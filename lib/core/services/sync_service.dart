import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Pushes locally-earned student data to the server. Everything here is
/// fire-and-forget: a failed push never blocks the app, and the local state
/// is re-pushed on the next login.
class SyncService {
  SyncService._();

  /// One-shot post-login/signup sync: gamification numbers (streak, XP) and
  /// the learner profile chosen during onboarding (class, board, subjects).
  static Future<void> syncAfterLogin() async {
    final api = SecureApiService();
    if (!api.isLoggedIn) return;
    final g = GamificationService();
    await api.pushProgress(xp: g.xp, streak: g.streak);

    final className = await LearnerProfileService.getSelectedClass();
    final board = await LearnerProfileService.getBoard();
    final subjects = await LearnerProfileService.getSubjects();
    if (className == null && board == null && subjects.isEmpty) return;
    await api.updateProfile(
      gradeLevel: className,
      schoolBoard: board,
      weakSubjects: subjects,
    );
  }
}
