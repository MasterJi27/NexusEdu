import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/providers/app_providers.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/daily_quiz_service.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/subject_progress_service.dart';

/// Aggregated dashboard state — replaces `DashboardScreen` 1080-LOC StatefulWidget
/// that called 4 services serially in `initState` + `setState`.
class DashboardState {
  const DashboardState({
    this.selectedClass,
    required this.isLoggedIn,
    required this.xp,
    required this.level,
    required this.levelProgress,
    required this.streak,
    required this.streakSaverUsed,
    required this.subjects,
    required this.quizDoneToday,
    this.daysLeft,
    this.weakestSubject,
  });

  final String? selectedClass;
  final bool isLoggedIn;
  final int xp;
  final int level;
  final double levelProgress;
  final int streak;
  final bool streakSaverUsed;
  final List<SubjectProgress> subjects;
  final bool quizDoneToday;
  final int? daysLeft;
  final SubjectProgress? weakestSubject;

  double get overallProgress {
    if (subjects.isEmpty) return 0;
    final total = subjects.fold(0, (s, e) => s + e.totalChapters);
    final done = subjects.fold(0, (s, e) => s + e.completedChapters);
    return total > 0 ? done / total : 0;
  }
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    final appSettings = ref.watch(appSettingsProvider);
    final secureApi = ref.watch(secureApiServiceProvider);

    // Parallel loads — previously sequential `await` chain in `_loadData`.
    final results = await Future.wait([
      LearnerProfileService.getSelectedClass(),
      GamificationService().load().then((_) => null),
      SubjectProgressService().load().then((_) => null),
      DailyQuizService().load().then((_) => null),
    ]);

    final selectedClass = results[0] as String?;
    final gamification = GamificationService();
    final subjects = SubjectProgressService().subjects;
    final quizDone = DailyQuizService().todayCompleted;

    final examDate = appSettings.examDate;
    int? daysLeft;
    if (examDate != null) {
      daysLeft = examDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) daysLeft = 0;
    }

    SubjectProgress? weakest;
    if (subjects.isNotEmpty) {
      weakest = subjects.reduce((a, b) => a.progress <= b.progress ? a : b);
    }

    return DashboardState(
      selectedClass: selectedClass,
      isLoggedIn: secureApi.isLoggedIn,
      xp: gamification.xp,
      level: gamification.level,
      levelProgress: gamification.levelProgress,
      streak: appSettings.streak,
      streakSaverUsed: appSettings.streakSaverUsed,
      subjects: subjects,
      quizDoneToday: quizDone,
      daysLeft: daysLeft,
      weakestSubject: weakest,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> setSelectedClass(String? cls) async {
    final current = state.value;
    if (current == null) return;
    await LearnerProfileService.setSelectedClass(cls);
    state = AsyncValue.data(
      DashboardState(
        selectedClass: cls,
        isLoggedIn: current.isLoggedIn,
        xp: current.xp,
        level: current.level,
        levelProgress: current.levelProgress,
        streak: current.streak,
        streakSaverUsed: current.streakSaverUsed,
        subjects: current.subjects,
        quizDoneToday: current.quizDoneToday,
        daysLeft: current.daysLeft,
        weakestSubject: current.weakestSubject,
      ),
    );
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
