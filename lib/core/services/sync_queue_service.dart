import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Offline outbox: work the app could not send while offline, flushed when
/// connectivity returns (and after every enqueue, in case it is already
/// online).
///
/// Item types:
///  - `attendance_mark` payload {sessionId, studentId, clientMarkedAt, lat, lng, isMocked}
///    (teacher's hotspot flow; posted to the attendance batch endpoint)
///  - `quiz_result`     payload {title, score, total, percent, takenAt}
///  - `note`            payload {title, content, latitude, longitude}
///
/// Items the server answers `ok` are dropped; failures stay queued for the
/// next flush. Queue is capped at [maxItems] (oldest dropped).
class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService instance = SyncQueueService._();

  static const _queueKey = 'sync_outbox';
  static const maxItems = 100;

  bool _flushing = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(items));
  }

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    final items = await _load();
    items.add({
      'type': type,
      'payload': payload,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (items.length > maxItems) {
      items.removeRange(0, items.length - maxItems);
    }
    await _save(items);
    unawaited(flush());
  }

  Future<int> count() async => (await _load()).length;

  /// Pushes queued items to the backend. Safe to call concurrently; one
  /// flush runs at a time and a failure simply leaves the queue for next
  /// time.
  Future<void> flush() async {
    if (_flushing) return;
    final api = SecureApiService();
    if (!api.isLoggedIn || !ConnectivityService.instance.online) return;
    _flushing = true;
    try {
      final items = await _load();
      if (items.isEmpty) return;
      final kept = <Map<String, dynamic>>[];
      final attendanceBySession = <String, List<Map<String, dynamic>>>{};
      final generic = <Map<String, dynamic>>[];
      for (final item in items) {
        if (item['type'] == 'attendance_mark') {
          final sessionId = (item['payload'] as Map)['sessionId'] as String?;
          if (sessionId != null) {
            attendanceBySession.putIfAbsent(sessionId, () => []).add(item);
          } else {
            kept.add(item);
          }
        } else {
          generic.add(item);
        }
      }
      for (final entry in attendanceBySession.entries) {
        final marks = entry.value
            .map((i) => Map<String, dynamic>.from(i['payload'] as Map))
            .toList();
        final result = await api.attendanceBatch(entry.key, marks);
        kept.addAll(retainUnacked(entry.value, result['results'] as List?));
      }
      if (generic.isNotEmpty) {
        final result = await api.syncQueue(
          generic
              .map((i) => {'type': i['type'], 'payload': i['payload']})
              .toList(),
        );
        kept.addAll(retainUnacked(generic, result['results'] as List?));
      }
      await _save(kept);
    } finally {
      _flushing = false;
    }
  }

  /// Server acks arrive in request order; items with a missing or failed ack
  /// are kept for retry.
  @visibleForTesting
  static List<Map<String, dynamic>> retainUnacked(
    List<Map<String, dynamic>> items,
    List<dynamic>? results,
  ) {
    if (results == null) return items;
    final kept = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final ack = i < results.length ? results[i] as Map : null;
      if (ack == null || ack['ok'] != true) kept.add(items[i]);
    }
    return kept;
  }
}
