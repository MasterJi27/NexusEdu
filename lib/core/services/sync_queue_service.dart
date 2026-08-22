import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

  // P1-23: injectable jitter Random for testability (was Random().nextInt inline).
  static Random _rnd = Random();
  @visibleForTesting
  static set rnd(Random r) => _rnd = r;
  @visibleForTesting
  static Random get rnd => _rnd;

  // Serializes every read-modify-write against the persisted queue —
  // `enqueue()` and `flush()` both do `_load()` then `_save()`, and without a
  // shared lock two concurrent calls (two enqueues, or an enqueue racing
  // flush's final save) can each read the same snapshot and have one save
  // silently overwrite the other's item.
  Future<void> _writeLock = Future.value();

  Future<T> _withLock<T>(Future<T> Function() action) async {
    final previous = _writeLock;
    final completer = Completer<void>();
    _writeLock = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('SyncQueueService: failed to load queue: $e');
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(items));
  }

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    await _withLock(() async {
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
    });
    unawaited(flush());
  }

  Future<int> count() async => (await _load()).length;

  /// Pushes queued items to the backend. Safe to call concurrently; one
  /// flush runs at a time and a failure simply leaves the queue for next
  /// time.
  ///
  /// 1M-scale: jitter + exponential backoff. Jitter spreads thundering herd
  /// on reconnect; keep flush retries behind backoff (e.g. `min(30s, (1<<attempt)*1s + jitter)`).
  Future<void> flush() async {
    if (_flushing) return;
    final api = SecureApiService();
    if (!api.isLoggedIn || !ConnectivityService.instance.online) return;
    _flushing = true;
    try {
      // Jitter before network: up to 1s random delay to avoid synchronized flush storms.
      // P1-23: use injectable _rnd for testability (was Random().nextInt).
      await Future.delayed(Duration(milliseconds: _rnd.nextInt(1000)));

      // Split lock: _load inside lock to get a consistent snapshot, network
      // outside lock so we don't hold the mutex during IO (which would block
      // concurrent enqueue), then re-enter lock for _save and merge any items
      // that arrived while the network was in flight.
      List<Map<String, dynamic>> snapshot = [];
      await _withLock(() async {
        snapshot = await _load();
      });
      if (snapshot.isEmpty) return;

      // --- network outside lock ---
      final kept = <Map<String, dynamic>>[];
      final attendanceBySession = <String, List<Map<String, dynamic>>>{};
      final generic = <Map<String, dynamic>>[];
      for (final item in snapshot) {
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
      // Collect unacked from snapshot; acked = snapshot - kept after network.
      final unackedSnapshot = <Map<String, dynamic>>[];
      // Items with missing/invalid sessionId are kept verbatim (no network).
      unackedSnapshot.addAll(kept);
      kept.clear();
      for (final entry in attendanceBySession.entries) {
        final marks = entry.value
            .map((i) => Map<String, dynamic>.from(i['payload'] as Map))
            .toList();
        final result = await api.attendanceBatch(entry.key, marks);
        unackedSnapshot.addAll(retainUnacked(entry.value, result['results'] as List?));
      }
      if (generic.isNotEmpty) {
        final result = await api.syncQueue(
          generic
              .map((i) => {'type': i['type'], 'payload': i['payload']})
              .toList(),
        );
        unackedSnapshot.addAll(retainUnacked(generic, result['results'] as List?));
      }

      // --- re-enter lock for _save: merge unackedSnapshot + any new items enqueued during network ---
      await _withLock(() async {
        final current = await _load();
        if (current.isEmpty) {
          await _save(unackedSnapshot);
          return;
        }
        // Build set of snapshot identities that were acked (i.e., in snapshot but not in unackedSnapshot).
        // Use jsonEncode as stable identity (createdAt + payload). This is O(n) and robust to object identity.
        final unackedKeys = unackedSnapshot.map((e) => jsonEncode(e)).toSet();
        final snapshotKeys = snapshot.map((e) => jsonEncode(e)).toSet();
        // Keep: (a) all unacked from snapshot, (b) any items in current that were NOT acked (i.e., new enqueues or unacked).
        // Equivalent to: current where key not in ackedKeys, but ensure unackedSnapshot items are preserved even if current diverged.
        final merged = <Map<String, dynamic>>[];
        // First add all unackedSnapshot (preserves order of snapshot unacked).
        merged.addAll(unackedSnapshot);
        // Then append any current items that are not part of the original snapshot (new enqueues).
        for (final item in current) {
          final key = jsonEncode(item);
          if (!snapshotKeys.contains(key) && !unackedKeys.contains(key)) {
            merged.add(item);
          }
        }
        // Cap total bytes via helper? Queue is maxItems capped elsewhere, but keep merged within maxItems.
        final toSave = merged.length > maxItems ? merged.sublist(merged.length - maxItems) : merged;
        await _save(toSave);
      });
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
