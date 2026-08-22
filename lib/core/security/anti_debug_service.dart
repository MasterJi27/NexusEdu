import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Low-level anti-debug / anti-tamper checks.
/// Runs early in `main()` (before runApp) and periodically via heartbeat.
/// If any check fails in `release` mode, session is wiped and app exits.
/// In `debug` mode we only log (so devs can still use debugger).
class AntiDebugService {
  static const _channel = MethodChannel('com.nexus.edu/security');
  static bool _lastPassed = true;
  static Timer? _periodic;
  static void Function(String reason)? _onViolation;

  static void setViolationCallback(void Function(String) cb) => _onViolation = cb;

  /// Call before `runApp` — synchronous-ish. Returns true if safe.
  static Future<bool> runStartupChecks() async {
    final violations = await _runAllChecks();
    if (violations.isNotEmpty) {
      await _handleViolations(violations, fatal: !kDebugMode);
      return false;
    }
    return true;
  }

  static void startPeriodic({Duration interval = const Duration(seconds: 30)}) {
    _periodic?.cancel();
    _periodic = Timer.periodic(interval, (_) async {
      final violations = await _runAllChecks();
      if (violations.isNotEmpty) {
        await _handleViolations(violations, fatal: false);
      }
    });
  }

  static void stopPeriodic() => _periodic?.cancel();

  static Future<List<String>> _runAllChecks() async {
    final out = <String>[];
    // Dart-level quick checks
    if (_isDartDebuggerAttached()) out.add('dart_debugger');
    if (await _isEmulator()) out.add('emulator');
    if (await _hasHookFrameworks()) out.add('hook_framework');

    // Native checks via MethodChannel (Kotlin/C++)
    try {
      final native = await _channel.invokeMethod<String>('runChecks');
      if (native != null && native.isNotEmpty && native != 'ok') {
        out.addAll(native.split(',').where((s) => s.isNotEmpty));
      }
    } on MissingPluginException {
      // Channel not registered (e.g. tests) — skip native.
    } catch (e) {
      debugPrint('[AntiDebug] native check error $e');
    }

    // Timing check is done by WsHeartbeat time-drift; also do quick self-check.
    if (await _hasTracerPid()) out.add('tracer_pid');
    if (await _hasFridaPort()) out.add('frida_port');

    return out;
  }

  static bool _isDartDebuggerAttached() {
    // In release, debugger should never be attached. kDebugMode is compile-time.
    bool attached = false;
    assert(() {
      // This block only runs in debug — try to detect debugger via
      // `isDebugging` workaround: check if timeline is paused?
      attached = false;
      return true;
    }());
    // Production heuristic: if `VM` service protocol present, suspect debugger.
    // We use `Platform.executableArguments` contains --enable-vm-service
    try {
      if (Platform.executableArguments.any((a) => a.contains('vm-service'))) {
        attached = true;
      }
    } catch (_) {}
    return attached;
  }

  static Future<bool> _isEmulator() async {
    try {
      final info = await _channel.invokeMethod<String>('isEmulator');
      return info == 'true';
    } catch (_) {
      // Fallback Dart heuristics
      final brand = Platform.operatingSystem;
      // Very rough: check for known emulator files (only on Android)
      if (!Platform.isAndroid) return false;
      const emuFiles = [
        '/proc/tty/drivers', // exists but content hints qemu
      ];
      for (final p in emuFiles) {
        try {
          if (await File(p).exists()) {
            final c = await File(p).readAsString();
            if (c.contains('goldfish') || c.contains('qemu')) return true;
          }
        } catch (_) {}
      }
      return brand.contains('emulator');
    }
  }

  static Future<bool> _hasHookFrameworks() async {
    // Check for Xposed/Frida files
    const suspects = [
      '/data/local/tmp/re.frida.server',
      '/data/local/tmp/frida',
      '/system/lib/libfrida-gadget.so',
      '/system/xbin/daemonsu',
      '/system/bin/su',
      '/system/app/Superuser.apk',
    ];
    for (final p in suspects) {
      try {
        if (await File(p).exists()) return true;
      } catch (_) {}
    }
    // Check loaded libs via /proc/self/maps for frida, xposed
    try {
      final maps = await File('/proc/self/maps').readAsString();
      if (maps.contains('frida') || maps.contains('xposed') || maps.contains('substrate')) return true;
    } catch (_) {}
    return false;
  }

  static Future<bool> _hasTracerPid() async {
    try {
      final status = await File('/proc/self/status').readAsString();
      for (final line in status.split('\n')) {
        if (line.startsWith('TracerPid:')) {
          final pid = int.tryParse(line.split(':')[1].trim()) ?? 0;
          if (pid != 0) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> _hasFridaPort() async {
    try {
      final result = await Socket.connect('127.0.0.1', 27042, timeout: const Duration(milliseconds: 800));
      result.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _handleViolations(List<String> violations, {required bool fatal}) async {
    final reason = violations.join(',');
    debugPrint('[AntiDebug] violations: $reason fatal=$fatal');
    _lastPassed = false;
    _onViolation?.call(reason);

    if (fatal) {
      // In release, wipe secure storage and kill.
      try {
        // Lazy import to avoid cycle — call via channel if available
        await _channel.invokeMethod('onTamper', {'reason': reason});
      } catch (_) {}
      // Give UI a chance to show, then exit
      await Future.delayed(const Duration(milliseconds: 600));
      // Hard exit — prevents further memory dumping
      try {
        exit(0);
      } catch (_) {
        // ignore
      }
      // Fallback: throw to crash zone
      throw Exception('Security violation: $reason');
    }
  }

  static bool get lastPassed => _lastPassed;
}
