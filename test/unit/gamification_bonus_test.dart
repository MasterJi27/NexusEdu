import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first quiz of the day earns the first-win XP bonus',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final g = GamificationService();
    await g.load();
    final xpBefore = g.xp;

    await g.recordQuizCompletion(4, totalQuestions: 5);

    expect(g.xp - xpBefore, 4 * 2 + GamificationService.firstWinBonusXp);
    expect(g.firstWinEarnedToday, true);
  });

  testWidgets('second quiz of the day does not re-award the bonus',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final g = GamificationService();
    await g.load();
    await g.recordQuizCompletion(5, totalQuestions: 5);
    final xpAfterFirst = g.xp;

    await g.recordQuizCompletion(5, totalQuestions: 5);

    expect(g.xp - xpAfterFirst, 5 * 2);
    expect(g.firstWinEarnedToday, true);
  });

  testWidgets('bonus resets on a new day (load compares dates)',
      (tester) async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'first_win_bonus_date': yesterday,
      'xp': 100,
    });
    final g = GamificationService();
    await g.load();

    expect(g.firstWinEarnedToday, false);
    await g.recordQuizCompletion(3, totalQuestions: 5);
    expect(g.xp, 100 + 3 * 2 + GamificationService.firstWinBonusXp);
  });
}
