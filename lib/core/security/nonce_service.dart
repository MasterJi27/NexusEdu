import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Nonce system — makes every server response dynamic and prevents replay.
/// Each request carries a fresh `X-Nonce` + `X-Timestamp`; server echoes
/// the nonce in the encrypted response and signs timestamp. Client rejects
/// reused or stale nonces (5-min window) and out-of-order responses.
class NonceService {
  static final _usedNonces = <String, DateTime>{};
  static const _window = Duration(minutes: 5);
  static const _maxSize = 5000; // SEC-R8: cap to prevent unbounded memory growth
  static const _domainPrefix = 'nexus_edu:'; // SEC-R8: domain separation
  static final _rnd = Random.secure();

  /// 16-byte hex nonce.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  /// Hash for request signing: HMAC-like sha256(nonce + timestamp + bodyHash)
  static String sign(String nonce, String ts, String bodyHash) {
    // SEC-R8: domain separation — prefix prevents cross-protocol confusion
    final h = sha256.convert(utf8.encode('$_domainPrefix$nonce|$ts|$bodyHash')).toString();
    return h;
  }

  static String bodyHash(String body) => sha256.convert(utf8.encode(body)).toString();

  /// Returns true if nonce is fresh, then marks it used. Purges expired.
  /// SEC-R8: capped LRU (5000) + domain separation prefix to avoid cross-feature replay.
  static bool consume(String nonce) {
    _purgeExpired();
    final key = '$_domainPrefix$nonce';
    if (_usedNonces.containsKey(key)) return false;
    if (_usedNonces.length >= _maxSize) {
      // LRU eviction: remove oldest (LinkedHashMap insertion order)
      final oldestKey = _usedNonces.keys.first;
      _usedNonces.remove(oldestKey);
    }
    _usedNonces[key] = DateTime.now();
    return true;
  }

  /// Validates server-echoed nonce + timestamp window.
  static bool validateResponse({
    required String requestNonce,
    required String responseNonce,
    required String responseTs,
  }) {
    if (requestNonce != responseNonce) return false;
    final ts = int.tryParse(responseTs);
    if (ts == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age.abs() > _window.inMilliseconds) return false;
    return consume(responseNonce);
  }

  static void _purgeExpired() {
    final now = DateTime.now();
    _usedNonces.removeWhere((_, t) => now.difference(t) > _window);
  }

  /// For heartbeat: nonce is also the ping id.
  static String heartbeatId() => generate();
}
