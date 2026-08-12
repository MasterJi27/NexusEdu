import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/features/feed/presentation/providers/feed_provider.dart';
import 'package:nexus_edu/features/ncert_solutions/presentation/screens/ncert_solutions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guest topic search falls back to local catalog when API fails',
      () async {
    SharedPreferences.setMockInitialValues({});
    // flutter_test blocks real HTTP with a 400 response, so the YouTube call
    // inside submitGuestTopic throws and the notifier must use local results.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(feedProvider.notifier);
    await notifier.build();

    await notifier.submitGuestTopic('quadratic equations');

    final state = container.read(feedProvider).requireValue;
    expect(state.videos, isNotEmpty,
        reason: 'local catalog should still answer the topic offline');
    expect(state.guestQuery, 'quadratic equations');
  });

  group('capRecentSolutions', () {
    Map<String, dynamic> entry(int i, {bool withText = true}) => {
          'class': '10',
          'subject': 'Physics',
          'chapter': 'Ch $i',
          'text': withText ? 'solution $i' : '',
        };

    test('keeps text for the newest entries only', () {
      final entries = List.generate(12, (i) => entry(i));
      capRecentSolutions(entries);
      for (var i = 0; i < 10; i++) {
        expect(entries[i]['text'], 'solution $i');
      }
      for (var i = 10; i < 12; i++) {
        expect(entries[i]['text'], '');
      }
    });

    test('leaves entries under the text limit untouched', () {
      final entries = List.generate(5, (i) => entry(i));
      capRecentSolutions(entries);
      for (var i = 0; i < 5; i++) {
        expect(entries[i]['text'], 'solution $i');
      }
    });

    test('isCachedOffline only for entries with text', () {
      expect(isCachedOffline(entry(0)), true);
      expect(isCachedOffline(entry(0, withText: false)), false);
    });
  });
}
