import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/services/app_settings.dart';

void main() {
  final day = DateTime(2026, 8, 9);

  String dateOf(DateTime d) => d.toIso8601String().substring(0, 10);

  DateTime addDays(int n) => DateTime(day.year, day.month, day.day + n);

  group('computeStreak', () {
    test('first activity sets streak to 1', () {
      expect(AppSettings.computeStreak(0, '', false, day), (1, false));
    });

    test('tryDecode handles json, legacy codec, and garbage', () {
      expect(AppSettings.tryDecode('{"a":1}'), {'a': 1});
      expect(AppSettings.tryDecode('title=AI & ML|content=diff'), {
        'title': 'AI & ML',
        'content': 'diff',
      });
      expect(AppSettings.tryDecode('garbage'), isNull);
    });

    test('same day keeps streak and saver state', () {
      expect(
        AppSettings.computeStreak(5, dateOf(day), false, day),
        (5, false),
      );
      expect(
        AppSettings.computeStreak(5, dateOf(day), true, day),
        (5, true),
      );
    });

    test('consecutive day increments and restores saver', () {
      expect(
        AppSettings.computeStreak(4, dateOf(addDays(-1)), false, day),
        (5, false),
      );
      expect(
        AppSettings.computeStreak(4, dateOf(addDays(-1)), true, day),
        (5, false),
      );
    });

    test('one missed day keeps streak and consumes the saver', () {
      expect(
        AppSettings.computeStreak(7, dateOf(addDays(-2)), false, day),
        (7, true),
      );
    });

    test('second missed day resets streak and re-arms the saver', () {
      expect(
        AppSettings.computeStreak(7, dateOf(addDays(-2)), true, day),
        (1, false),
      );
    });

    test('longer gap resets streak and re-arms the saver', () {
      expect(
        AppSettings.computeStreak(12, dateOf(addDays(-5)), false, day),
        (1, false),
      );
      expect(
        AppSettings.computeStreak(12, dateOf(addDays(-5)), true, day),
        (1, false),
      );
    });

    test('unparseable date starts fresh', () {
      expect(AppSettings.computeStreak(3, 'not-a-date', false, day), (1, false));
    });
  });
}
