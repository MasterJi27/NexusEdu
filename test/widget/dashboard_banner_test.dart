import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/features/dashboard/presentation/screens/dashboard_screen.dart';

void main() {
  String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

  String daysAgo(int n) {
    final d = DateTime.now().subtract(Duration(days: n));
    return d.toIso8601String().substring(0, 10);
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    await AppSettings.instance.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first-win nudge shows for a fresh student', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpDashboard(tester);
    expect(
      find.textContaining('Earn your first win'),
      findsOneWidget,
    );
  });

  testWidgets('nudge hides once the daily quiz is done', (tester) async {
    // Real DailyQuizService signal, not the old disconnected manual
    // checklist checkbox — see dashboard_screen.dart's _TodayPlan/
    // _StreakBanner, which now both read DailyQuizService.todayCompleted
    // instead of a separate "daily_plan_quiz" key nothing else ever set.
    SharedPreferences.setMockInitialValues({
      'today_quiz_completed': true,
      'last_quiz_date': DateTime.now().toIso8601String(),
    });
    await pumpDashboard(tester);
    expect(find.textContaining('Earn your first win'), findsNothing);
  });

  testWidgets('shield banner appears when a day was skipped', (tester) async {
    SharedPreferences.setMockInitialValues({
      'study_streak': 5,
      'last_study_date': daysAgo(2),
      'streak_saver_used': false,
    });
    await pumpDashboard(tester);
    expect(
      find.textContaining('shield saved your 5-day streak'),
      findsOneWidget,
    );
  });

  testWidgets('no banner for an active multi-day streak', (tester) async {
    SharedPreferences.setMockInitialValues({
      'study_streak': 5,
      'last_study_date': todayKey(),
      'streak_saver_used': false,
    });
    await pumpDashboard(tester);
    expect(find.textContaining('shield saved'), findsNothing);
    expect(find.textContaining('Earn your first win'), findsNothing);
  });

  testWidgets('first-win XP bonus celebration shows after the daily quiz',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'study_streak': 3,
      'last_study_date': todayKey(),
      'streak_saver_used': false,
      'first_win_bonus_date': todayKey(),
      'xp': 100,
    });
    final g = GamificationService();
    await g.load();
    expect(g.firstWinEarnedToday, true);
    await pumpDashboard(tester);
    expect(
      find.textContaining('+15 XP bonus'),
      findsOneWidget,
    );
  });
}
