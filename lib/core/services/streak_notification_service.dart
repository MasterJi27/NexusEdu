import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local streak-risk notification (UX-RESEARCH item 3): a daily 7pm reminder
/// tied to the student's own streak, never a broadcast. Enabled/disabled from
/// the Settings "Streak alerts" toggle; scheduling is local — no backend.
class StreakNotificationService {
  StreakNotificationService._();
  static final StreakNotificationService instance =
      StreakNotificationService._();

  static const _streakAlertId = 1001;
  static const _enabledKey = 'settings_streak_alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzReady = false;
  bool _enabledPref = true;

  bool get enabled => _enabledPref;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabledPref = prefs.getBool(_enabledKey) ?? true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
    );
    _initialized = true;

    if (_enabledPref) {
      await _requestPermission();
      await schedule();
    } else {
      await cancel();
    }
  }

  Future<void> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.requestNotificationsPermission();
  }

  Future<void> _ensureTz() async {
    if (_tzReady) return;
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC; the reminder still fires, at the UTC hour.
      tz.setLocalLocation(tz.UTC);
    }
    _tzReady = true;
  }

  /// 7pm local, repeating daily. The streak count is read at schedule time so
  /// the message reflects the student's current run.
  Future<void> schedule() async {
    if (!_initialized) return;
    await _ensureTz();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final streak = AppSettings.instance.streak;
    final body = streak > 0
        ? 'A 5-minute session keeps your $streak-day streak. Do it today!'
        : 'Start your streak with a 5-minute session today.';
    await _plugin.zonedSchedule(
      id: _streakAlertId,
      title: 'Your streak needs you today',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_alerts',
          'Streak alerts',
          channelDescription: 'Daily reminders to protect your study streak',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_alert',
    );
  }

  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _streakAlertId);
  }

  /// Called by the Settings toggle.
  Future<void> setEnabled(bool value) async {
    _enabledPref = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!_initialized) return;
    if (value) {
      await _requestPermission();
      await schedule();
    } else {
      await cancel();
    }
  }
}
