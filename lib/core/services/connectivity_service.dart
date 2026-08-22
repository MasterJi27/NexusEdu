import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Backend-reachability probe — the signal that actually matters for AI
/// features and sync (raw wifi state is useless when the server is down).
/// Pings the health endpoint and caches the verdict for 15s so the AI gate,
/// the offline banner and the reconnect-sync trigger share one answer instead
/// of each hammering the server.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  static const _cacheTtl = Duration(seconds: 15);
  static const _probeTimeout = Duration(seconds: 6);

  bool _online = true;
  DateTime? _lastProbe;
  // P1-09: store periodic poll so it can be cancelled on dispose (was leaked).
  Timer? _poll;

  bool get online => _online;

  /// Seeded from [main] with an immediate probe plus a light background poll
  /// so the banner flips on/off without any screen doing its own polling.
  void start() {
    check();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  // AppLifecycle pause handling: polling should be paused when app is in
  // background to save battery/bandwidth. Wire via WidgetsBindingObserver
  // or AppLifecycleListener (didChangeAppLifecycleState):
  //   paused/inactive -> _poll?.cancel()
  //   resumed -> start()
  // TODO: add AppLifecycleListener in main.dart or wrap ConnectivityService with
  // WidgetsBindingObserver to auto-pause/resume _poll.

  /// Returns the current verdict, re-probing only when the cached one is
  /// stale. Callers that need a hard answer (the AI gate) await this.
  Future<bool> check() async {
    final last = _lastProbe;
    if (last != null && DateTime.now().difference(last) < _cacheTtl) {
      return _online;
    }
    _lastProbe = DateTime.now();
    var online = false;
    try {
      final r = await http
          .get(Uri.parse('${SecureApiService.baseUrl}/api/health'))
          .timeout(_probeTimeout);
      online = r.statusCode == 200;
    } catch (_) {
      online = false;
    }
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
    return online;
  }
}
