import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Relays uncaught crashes to the backend's `/api/errors` endpoint, which
/// logs them into the same Application Insights pipeline the server already
/// has (see backend/src/routes/errors.ts). There's no real Firebase project
/// behind `google-services.json` (it's a placeholder), so wiring Crashlytics
/// against it would just be another non-functional integration — this reuses
/// infrastructure that's actually live instead.
///
/// Deliberately fire-and-forget: a failure reporting a crash must never
/// throw, block, or cause a second crash.
class ErrorReportingService {
  ErrorReportingService._();

  static void report(Object error, StackTrace? stack, {bool fatal = false}) {
    if (kDebugMode) {
      // Surfaced in the IDE/console already; avoid spamming the backend on
      // every hot-reload-triggered exception during development.
      return;
    }
    unawaited(_send(error, stack, fatal));
  }

  static Future<void> _send(Object error, StackTrace? stack, bool fatal) async {
    try {
      await http
          .post(
            Uri.parse('${SecureApiService.baseUrl}/api/errors'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': error.toString(),
              if (stack != null) 'stack': stack.toString(),
              'fatal': fatal,
              'platform': Platform.operatingSystem,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // No connectivity, backend down, etc. — nothing useful to do with a
      // failure to report a failure.
    }
  }
}
