import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_edu/core/services/sync_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue persists items and count reflects them', () async {
    await SyncQueueService.instance.enqueue('quiz_result', {
      'title': 'Maths test',
      'score': 3,
      'total': 5,
    });
    await SyncQueueService.instance.enqueue('attendance_mark', {
      'sessionId': 's1',
      'studentId': 'u1',
      'clientMarkedAt': '2026-08-09T10:00:00Z',
    });

    expect(await SyncQueueService.instance.count(), 2);
  });

  test('queue caps at maxItems dropping the oldest', () async {
    for (var i = 0; i < SyncQueueService.maxItems + 10; i++) {
      await SyncQueueService.instance.enqueue('quiz_result', {
        'title': 'Q$i',
        'score': 1,
        'total': 1,
      });
    }
    expect(await SyncQueueService.instance.count(), SyncQueueService.maxItems);
  });

  test('items with a successful ack are dropped, failures kept', () {
    final items = [
      {
        'type': 'quiz_result',
        'payload': {'title': 'a'},
      },
      {
        'type': 'quiz_result',
        'payload': {'title': 'b'},
      },
      {
        'type': 'quiz_result',
        'payload': {'title': 'c'},
      },
    ];

    final kept = SyncQueueService.retainUnacked(
      items,
      [
        {'type': 'quiz_result', 'ok': true},
        {'type': 'quiz_result', 'ok': false},
        {'type': 'quiz_result', 'ok': true},
      ],
    );

    expect(kept, hasLength(1));
    expect((kept.single['payload'] as Map)['title'], 'b');
  });

  test('missing server response keeps every item for retry', () {
    final items = [
      {
        'type': 'quiz_result',
        'payload': {'title': 'a'},
      },
    ];

    expect(
      SyncQueueService.retainUnacked(items, null),
      hasLength(1),
    );
    expect(SyncQueueService.retainUnacked(items, []), hasLength(1));
  });
}
