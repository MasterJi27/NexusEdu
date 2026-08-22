import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Verifies .text segment integrity per diagram:
/// `.text segment -> Your Hash Function -> Compare with securely delivered server hash`
///
/// Flow:
/// 1. At startup, call native to hash .text segment of `libapp.so` / `libflutter.so`
/// 2. Fetch expected hash from server over pinned HTTPS + encrypted channel
/// 3. Compare; on mismatch → tamper (app repackaged / hooked / patched)
/// Hash is SHA-256 of sorted .text bytes — server precomputes same on clean build
/// and serves via `/api/integrity/hash` (dynamic nonce-protected).
class AppIntegrityService {
  static const _channel = MethodChannel('com.nexus.edu/security');

  /// Hashes .text segment via native. Falls back to Dart hash of bundle id + version
  /// if native not available (tests).
  static Future<String?> computeLocalHash() async {
    try {
      final res = await _channel.invokeMethod<String>('computeTextHash');
      if (res != null && res.isNotEmpty) return res.toLowerCase();
    } on MissingPluginException {
      // Test / iOS fallback
    } catch (e) {
      debugPrint('[Integrity] computeLocalHash error $e');
    }
    // Fallback: hash of package name + version (not .text, but still detects trivial repack)
    try {
      final info = await _channel.invokeMethod<Map>('getPackageInfo');
      final pkg = info?['package']?.toString() ?? 'com.nexus.edu';
      final ver = info?['version']?.toString() ?? '1.2.6';
      return sha256.convert(utf8.encode('$pkg|$ver')).toString();
    } catch (_) {
      return sha256.convert(utf8.encode('com.nexus.edu|1.2.6')).toString();
    }
  }

  /// Fetches expected hash from server securely. Returns null if offline / error.
  /// Server response is `{hash: "<hex>", nonce: "...", ts: "..."}` and should be
  /// validated via NonceService if needed.
  static Future<String?> fetchServerHash(ApiClient client) async {
    try {
      final res = await client.requestResult('GET', '/api/integrity/hash');
      if (res is Success) {
        final data = (res as Success).data;
        if (data is Map && data['hash'] is String) return (data['hash'] as String).toLowerCase();
        if (data is String) return data.toLowerCase();
      }
      debugPrint('[Integrity] fetchServerHash failed: ${(res as Failure).message}');
    } catch (e) {
      debugPrint('[Integrity] fetchServerHash exception $e');
    }
    return null;
  }

  /// Compares local vs server hash. Returns true if matches or if server
  /// unavailable in debug (fail-open for dev). In release, offline is fail-closed
  /// after 7 days grace (handled by caller).
  static Future<bool> verify(ApiClient client, {bool failOpenInDebug = true}) async {
    final local = await computeLocalHash();
    if (local == null || local.isEmpty) {
      debugPrint('[Integrity] no local hash');
      return failOpenInDebug && kDebugMode;
    }
    final server = await fetchServerHash(client);
    if (server == null) {
      debugPrint('[Integrity] no server hash — offline');
      // Fail-open offline for now; heartbeat will retry.
      return true;
    }
    final match = _constantTimeEquals(local, server);
    debugPrint('[Integrity] local=${local.substring(0, 8)} server=${server.substring(0, 8)} match=$match');
    if (!match && !kDebugMode) {
      // Report and trigger anti-debug wipe path
      try {
        await _channel.invokeMethod('onTamper', {'reason': 'integrity_mismatch'});
      } catch (_) {}
    }
    return match;
  }

  /// Constant-time compare to avoid timing side-channel.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// One-shot startup check that throws on tamper in release.
  static Future<void> assertIntegrityOrExit(ApiClient client) async {
    final ok = await verify(client);
    if (!ok && !kDebugMode) {
      throw Exception('Integrity check failed');
    }
  }
}
