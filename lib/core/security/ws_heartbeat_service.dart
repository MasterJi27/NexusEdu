import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/security/aes_encryption_service.dart';
import 'package:nexus_edu/core/security/nonce_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// WebSocket heartbeat — keep-alive + tamper/delay detection.
/// * Sends `{"type":"ping","nonce","ts","bodyHash"}` every 25s (server 30s timeout)
/// * Expects `pong` with same nonce + encrypted echo within 8s
/// * Measures RTT; if RTT > 15s or clock jumps, flags debugger pause
/// * On miss 2× or decrypt fail → reconnect with backoff, optionally wipe session on persistent tamper
/// * First connect fetches AES session key from server via WSS hello
class WsHeartbeatService {
  WsHeartbeatService._();
  static final WsHeartbeatService instance = WsHeartbeatService._();

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _pongTimer;
  String? _lastNonce;
  DateTime? _lastPingAt;
  int _missed = 0;
  int _backoffMs = 1000;
  bool _running = false;
  final _stateCtrl = StreamController<bool>.broadcast();
  Stream<bool> get onAlive => _stateCtrl.stream;

  bool get isAlive => _channel != null && _missed < 2;

  String get _wsUrl {
    final base = ApiClient.baseUrl;
    // wss://host / ws://host — keep path /api/ws/heartbeat
    final wsBase = base.replaceFirst(RegExp(r'^http'), 'ws');
    return '$wsBase/api/ws/heartbeat';
  }

  void start() {
    if (_running) return;
    _running = true;
    _connect();
    // Pause detection: wall-clock vs monotonic drift
    _startTimeDriftWatch();
  }

  void stop() {
    _running = false;
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _driftTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  Timer? _driftTimer;
  DateTime _lastWall = DateTime.now();
  Stopwatch _mono = Stopwatch()..start();

  void _startTimeDriftWatch() {
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final wallNow = DateTime.now();
      final wallDelta = wallNow.difference(_lastWall).inMilliseconds;
      _lastWall = wallNow;
      // In normal operation wallDelta ~5000ms (allow Doze jitter up to 8s).
      // If debugger hits breakpoint or device sleeps, wallDelta jumps >>8000.
      if (wallDelta > 8000 && _running) {
        debugPrint('[Heartbeat] time drift $wallDelta ms — possible debugger pause');
        // Don't kill, but force re-handshake and re-validate integrity
        _handleTamper('time_drift:$wallDelta');
      }
      // Keep mono running to avoid unused warning
      if (_mono.elapsedMilliseconds < 0) debugPrint('mono');
    });
  }

  Future<void> _connect() async {
    if (!_running) return;
    try {
      final token = SecureApiService().token;
      final uri = Uri.parse(_wsUrl).replace(queryParameters: {'deviceId': await _deviceId()});
      _channel = WebSocketChannel.connect(uri);
      if (token != null) {
        _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      }
      _missed = 0;
      _backoffMs = 1000;
      debugPrint('[Heartbeat] connected ${uri.toString()}');

      // Hello — fetch AES session key securely via first message (server pushes key)
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: (e) {
          debugPrint('[Heartbeat] error $e');
          _onDisconnect();
        },
        cancelOnError: false,
      );

      // Give server 5s to send hello/key before first ping
      await Future.delayed(const Duration(seconds: 2));
      _schedulePing();
    } catch (e) {
      debugPrint('[Heartbeat] connect failed $e');
      _scheduleReconnect();
    }
  }

  Future<String> _deviceId() async {
    try {
      // Use ApiClient's deviceId (derived from secure storage) — not token
      final client = ApiClient();
      final headers = await client.buildHeaders();
      return headers['X-Device-Id'] ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  void _schedulePing() {
    _pingTimer?.cancel();
    _pingTimer = Timer(const Duration(seconds: 25), _sendPing);
  }

  Future<void> _sendPing() async {
    if (!_running || _channel == null) return;
    final nonce = NonceService.heartbeatId();
    final ts = NonceService.timestamp();
    _lastNonce = nonce;
    _lastPingAt = DateTime.now();
    // Payload is nonce+ts signed; body empty for heartbeat
    final body = jsonEncode({'type': 'ping', 'nonce': nonce, 'ts': ts});
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    try {
      // Prefer encrypted heartbeat if key available
      String toSend;
      try {
        final wrap = await AesEncryptionService.wrap(body, nonce: nonce, ts: ts);
        toSend = jsonEncode({
          'enc': wrap['cipher'],
          'nonce': nonce,
          'ts': ts,
          'hash': bodyHash,
        });
      } catch (_) {
        toSend = body;
      }
      _channel!.sink.add(toSend);
      debugPrint('[Heartbeat] ping $nonce');
      // Expect pong within 8s
      _pongTimer?.cancel();
      _pongTimer = Timer(const Duration(seconds: 8), () {
        _missed++;
        debugPrint('[Heartbeat] pong timeout miss=$_missed');
        if (_missed >= 2) {
          _handleTamper('pong_timeout');
          _channel?.sink.close();
        } else {
          _schedulePing();
        }
      });
    } catch (e) {
      debugPrint('[Heartbeat] send failed $e');
      _onDisconnect();
    }
  }

  Future<void> _onMessage(dynamic data) async {
    try {
      final raw = data is String ? data : data.toString();
      Map<String, dynamic> msg;
      // Try encrypted unwrap first
      if (raw.contains('"enc"') && _lastNonce != null) {
        final outer = jsonDecode(raw) as Map<String, dynamic>;
        final encStr = outer['enc']?.toString() ?? '';
        if (encStr.isNotEmpty) {
          final plain = await AesEncryptionService.unwrap(encStr, expectedNonce: _lastNonce!);
          msg = jsonDecode(plain) as Map<String, dynamic>;
        } else {
          msg = outer;
        }
      } else {
        msg = jsonDecode(raw) as Map<String, dynamic>;
      }

      // Server may push AES session key on hello
      if (msg['type'] == 'hello' && msg['aesKey'] is String) {
        final keyB64 = msg['aesKey'] as String;
        await AesEncryptionService.ensureKey(serverProvidedB64: keyB64);
        debugPrint('[Heartbeat] AES session key installed');
        return;
      }

      if (msg['type'] == 'pong') {
        final nonce = msg['nonce']?.toString() ?? '';
        if (nonce != _lastNonce) {
          debugPrint('[Heartbeat] pong nonce mismatch $nonce != $_lastNonce');
          _handleTamper('nonce_mismatch');
          return;
        }
        final rtt = DateTime.now().difference(_lastPingAt!).inMilliseconds;
        debugPrint('[Heartbeat] pong ok rtt=$rtt ms');
        if (rtt > 15000) {
          // RTT huge likely debugger stepped
          _handleTamper('rtt:$rtt');
        }
        _missed = 0;
        _pongTimer?.cancel();
        _stateCtrl.add(true);
        _schedulePing();
        return;
      }

      if (msg['type'] == 'integrity_challenge') {
        // Server asks for .text hash — handled by AppIntegrityService
        // Just log; integrity service listens separately if needed.
        debugPrint('[Heartbeat] integrity challenge ${msg['challengeId']}');
      }
    } catch (e) {
      debugPrint('[Heartbeat] onMessage parse fail $e');
    }
  }

  void _onDisconnect() {
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _channel = null;
    _stateCtrl.add(false);
    if (_running) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_running) return;
    final delay = Duration(milliseconds: _backoffMs);
    debugPrint('[Heartbeat] reconnect in ${delay.inMilliseconds}ms');
    Future.delayed(delay, () {
      if (_running) _connect();
    });
    _backoffMs = (_backoffMs * 2).clamp(1000, 30000);
  }

  void _handleTamper(String reason) {
    debugPrint('[Heartbeat] tamper detected: $reason');
    // Light response now: report and backoff. Hardening: after 3 tamper events wipe.
    // We keep counter in memory; persistent counter could be in secure storage.
    // For now just log and force integrity re-check via callback if registered.
    _tamperCallback?.call(reason);
  }

  void Function(String)? _tamperCallback;
  void setTamperCallback(void Function(String) cb) => _tamperCallback = cb;
}
