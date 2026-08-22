import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Foreground poller for live-class notifications. The backend has no push
/// infrastructure yet (no FCM), so the app polls the in-app notification
/// stream while running:
///
///  - Foreground: only the Classroom-tab badge ([liveUnreadCount]) updates —
///    you're already looking at the app, a popup would be noise.
///  - Background: a brand-new `live_class` entry also fires one local
///    notification (deduped per notification id for the app run).
///
/// Lifecycle-aware and leak-free: the timer is created on [start], cancelled
/// on pause/detach/inactive, restarted on resume with an immediate poll, and
/// never outlives a backgrounded app.
class LiveClassNotificationPoller extends ChangeNotifier
    with WidgetsBindingObserver {
  LiveClassNotificationPoller._();
  static final LiveClassNotificationPoller instance =
      LiveClassNotificationPoller._();

  static const _pollInterval = Duration(seconds: 20);
  static const _channelId = 'live_class_alerts';
  static const _channelName = 'Live class alerts';
  static const _payload = 'live_class';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Set<String> _handledIds = {};
  Timer? _timer;
  bool _started = false;
  bool _initialized = false;
  bool _appInForeground = true;
  int _liveUnreadCount = 0;

  /// Set by main() to route a tapped notification (e.g. to the Classroom
  /// tab) without the poller importing the app layer.
  void Function()? onTap;

  /// Unread live-class notifications from the last poll — drives the
  /// Classroom-tab badge.
  int get liveUnreadCount => _liveUnreadCount;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _initPlugin();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll();
  }

  void _initPlugin() async {
    if (_initialized) return;
    _initialized = true;
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
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) onTap?.call();
      },
    );
    // Cold start: a tap that launched the app arrives before any callback is
    // registered — the launch-details API is the only way to learn about it.
    // The frame callback defers routing until the router exists.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload == _payload) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onTap?.call());
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Live classes started by your teachers',
          importance: Importance.high,
        ),
      );
      await android.requestNotificationsPermission();
    }
  }

  Future<void> _poll() async {
    if (!SecureApiService().isLoggedIn || !ConnectivityService.instance.online) {
      return;
    }
    try {
      final result = await SecureApiService().getNotifications();
      final items = (result['items'] as List?) ?? const [];
      var liveUnread = 0;
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        if (item['type'] != 'live_class') continue;
        final id = item['id'] as String?;
        final read = item['readAt'] != null;
        if (!read) liveUnread++;
        if (!read && id != null && _handledIds.add(id) && !_appInForeground) {
          _showLocalNotification(item);
        }
      }
      if (liveUnread != _liveUnreadCount) {
        _liveUnreadCount = liveUnread;
        notifyListeners();
      }
    } catch (_) {
      // Transient failure — the next tick retries; never surface.
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> item) async {
    if (!_initialized) return;
    final hash = (item['id'] as String?)?.hashCode ?? 2001;
    final id = hash & 0x7fffffff;
    await _plugin.show(
      id: id,
      title: item['title'] as String? ?? 'Live class started',
      body: item['body'] as String?,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Live classes started by your teachers',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: _payload,
    );
  }

  /// Logout: forget every seen notification id and clear the badge so the
  /// next account starts clean — the dedupe set and unread count are
  /// session-scoped state, not device state.
  void reset() {
    _handledIds.clear();
    _liveUnreadCount = 0;
    notifyListeners();
  }

  /// Immediate re-poll — used after a client-side "mark all read" so the
  /// badge does not disagree with the bell for up to a poll interval.
  void refreshNow() {
    unawaited(_poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = Timer.periodic(_pollInterval, (_) => _poll());
      _poll();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}