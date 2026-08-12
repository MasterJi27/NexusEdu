import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/app/router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/services/error_reporting_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/streak_notification_service.dart';
import 'package:nexus_edu/core/services/sync_service.dart';
import 'package:nexus_edu/core/services/sync_queue_service.dart';
import 'package:nexus_edu/core/services/youtube_discovery_service.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';

// Fonts are bundled in assets/fonts (pubspec), so runtime fetching is off:
// google_fonts throws loudly if a requested variant is missing instead of
// silently falling back, and the first frame no longer waits on a network
// round-trip. See DESIGN.md section 03 and the comment in app_theme.dart.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global crash capture — see ErrorReportingService for why this reports to
  // the backend instead of Crashlytics. FlutterError covers framework-level
  // errors (build/layout/paint); PlatformDispatcher and runZonedGuarded below
  // between them cover everything else (async callbacks, platform channels).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorReportingService.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    ErrorReportingService.report(error, stack, fatal: true);
    return true;
  };

  await runZonedGuarded(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    // The whole app is built for a single-handed phone flow; landscape splits
    // the reading column across a wide screen (the Smart Notes "wide screen"
    // bug). Lock to portrait unless the device is a tablet (>= 600dp width),
    // where a two-pane layout is still usable.
    final size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final isTablet = size.shortestSide >= 600 * WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (!isTablet) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    try {
      await dotenv.load(fileName: '.env');
    } catch (error) {
      debugPrint('Dotenv load skipped: $error');
    }

    // These four reads are independent of each other and of dotenv, so they run
    // concurrently instead of one-after-another. Two more calls used to sit in
    // this chain (`AiService.init()`, `AiChatService().init()`) that did
    // nothing at all — they have been removed.
    await Future.wait([
      SecureApiService().init(),
      YoutubeDiscoveryService.init(),
      AppSettings.instance.load(),
      AuthState.instance.load(),
    ]);

    // After settings are loaded (streak count is read at schedule time).
    await StreakNotificationService.instance.init();

    // Backend-reachability probe drives the offline banner, the AI gates and
    // the reconnect sync below; start it before the first frame.
    ConnectivityService.instance.start();

    // When connectivity returns, push locally-earned progress (gamification +
    // learner profile) and the offline outbox (quiz results, hotspot
    // attendance marks) that accumulated while offline. Notes sync their own
    // queue when the notes screen loads.
    var wasOnline = ConnectivityService.instance.online;
    ConnectivityService.instance.addListener(() {
      final nowOnline = ConnectivityService.instance.online;
      if (nowOnline && !wasOnline && SecureApiService().isLoggedIn) {
        SyncService.syncAfterLogin();
        SyncQueueService.instance.flush();
      }
      wasOnline = nowOnline;
    });

    runApp(const ProviderScope(child: NexusEduApp()));
  }, (error, stack) {
    ErrorReportingService.report(error, stack, fatal: true);
  });
}

class NexusEduApp extends StatelessWidget {
  const NexusEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Nexus Edu',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppSettings.instance.themeMode,
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
