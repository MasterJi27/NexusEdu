import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:nexus_edu/features/auth/presentation/screens/login_screen.dart';
import 'package:nexus_edu/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:nexus_edu/features/auth/presentation/screens/signup_screen.dart';
import 'package:nexus_edu/features/ai_usage/presentation/screens/ai_usage_screen.dart';
import 'package:nexus_edu/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:nexus_edu/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:nexus_edu/features/navigation/main_navigation.dart';
import 'package:nexus_edu/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nexus_edu/features/dashboard/presentation/screens/feature_gallery_screen.dart';
import 'package:nexus_edu/features/elearning/presentation/screens/class_selection_screen.dart';
import 'package:nexus_edu/features/elearning/presentation/screens/subject_selection_screen.dart';
import 'package:nexus_edu/features/elearning/presentation/screens/topic_learning_screen.dart';
import 'package:nexus_edu/features/elearning/presentation/screens/topic_list_screen.dart';
import 'package:nexus_edu/features/feed/presentation/screens/ai_feed_screen.dart';
import 'package:nexus_edu/features/tutor/presentation/screens/tutor_chat_screen.dart';
import 'package:nexus_edu/features/notes/presentation/screens/notes_screen.dart';
import 'package:nexus_edu/features/notes/presentation/screens/smart_note_editor_screen.dart';
import 'package:nexus_edu/features/profile/presentation/screens/profile_screen.dart';
import 'package:nexus_edu/features/focus/presentation/screens/focus_screen.dart';
import 'package:nexus_edu/features/scanner/presentation/screens/ai_scanner_screen.dart';
import 'package:nexus_edu/features/scanner/presentation/screens/youtube_summary_screen.dart';
import 'package:nexus_edu/features/gamification/presentation/screens/leaderboard_screen.dart';
import 'package:nexus_edu/features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import 'package:nexus_edu/features/parent/presentation/screens/parent_dashboard_screen.dart';
import 'package:nexus_edu/features/flashcards/presentation/screens/flashcard_deck_screen.dart';
import 'package:nexus_edu/features/flashcards/presentation/screens/flashcard_review_screen.dart';
import 'package:nexus_edu/features/spaced_repetition/presentation/screens/spaced_repetition_screen.dart';
import 'package:nexus_edu/features/ncert_solutions/presentation/screens/ncert_solutions_screen.dart';
import 'package:nexus_edu/features/jee_neet_trainer/presentation/screens/jee_neet_trainer_screen.dart';
import 'package:nexus_edu/features/ai_study_planner/presentation/screens/ai_study_planner_screen.dart';
import 'package:nexus_edu/features/smart_revision/presentation/screens/smart_revision_screen.dart';
import 'package:nexus_edu/features/mock_test/presentation/screens/mock_test_screen.dart';
import 'package:nexus_edu/features/offline_exam/presentation/screens/offline_exam_screen.dart';
import 'package:nexus_edu/features/quiz_generator/presentation/screens/quiz_generator_screen.dart';
import 'package:nexus_edu/features/multi_lang_tutor/presentation/screens/multi_lang_tutor_screen.dart';
import 'package:nexus_edu/features/math_word_solver/presentation/screens/math_word_solver_screen.dart';
import 'package:nexus_edu/features/privacy_policy/presentation/screens/privacy_policy_screen.dart';
import 'package:nexus_edu/features/settings/presentation/screens/settings_screen.dart';
import 'package:nexus_edu/features/daily_quiz/presentation/screens/daily_quiz_screen.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/attendance_session_screen.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/mark_attendance_screen.dart';
import 'package:nexus_edu/features/classroom/presentation/screens/classroom_screen.dart';

/// Public routes reachable without signing in (and while signed out).
const _authRoutes = {'/login', '/signup', '/forgot-password', '/reset-password'};

/// Pre-auth welcome carousel. Guests can browse freely after accepting privacy.
const _entryRoutes = {'/welcome'};

/// Central app router with a state-driven auth/onboarding guard.
final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/welcome',
    refreshListenable: AuthState.instance,
    redirect: (context, state) async {
      final auth = AuthState.instance;
      final loc = state.matchedLocation;

      if (!auth.isLoggedIn) {
        // Everyone starts at the welcome flow, even returning guests — the
        // sign-in / sign-up entry has to stay visible. Guests can browse
        // freely once they have accepted privacy.
        if (_entryRoutes.contains(loc) ||
            _authRoutes.contains(loc) ||
            loc == '/privacy-policy' ||
            auth.privacyAccepted) {
          return null;
        }
        return '/welcome';
      }

      if (!auth.privacyAccepted) {
        return loc == '/privacy-policy' ? null : '/privacy-policy?firstTime=1';
      }

      // The profile onboarding (grade/board/subjects) is student-specific.
      if (!auth.onboardingDone && auth.needsProfileOnboarding) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // Role-based route gating: teacher/parent surfaces are off-limits for
      // every other role. Guests (role null) keep the student experience and
      // are treated as students below.
      final role = auth.selectedRole ?? auth.user?.role.name ?? 'student';
      if (loc == '/teacher-dashboard' && role != 'teacher') return auth.roleHome;
      if (loc == '/parent-dashboard' && role != 'parent') return auth.roleHome;
      if ((loc == '/attendance' || loc == '/attendance/session') &&
          role != 'teacher') {
        return auth.roleHome;
      }
      if (loc == '/mark-attendance' && role == 'parent') return auth.roleHome;

      if (_authRoutes.contains(loc)) return auth.roleHome;
      if (_entryRoutes.contains(loc)) return auth.roleHome;
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            state.error?.toString() ?? 'Route not found: ${state.uri}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
          initialRole: state.uri.queryParameters['role'],
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/feed', builder: (context, state) => const AiFeedScreen()),
          GoRoute(path: '/tutor', builder: (context, state) => const TutorChatScreen()),
          GoRoute(path: '/notes', builder: (context, state) => const NotesScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/classroom', builder: (context, state) => const ClassroomScreen()),
        ],
      ),
      GoRoute(path: '/note-editor', builder: (context, state) => const SmartNoteEditorScreen()),
      GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
      GoRoute(path: '/scanner', builder: (context, state) => const AiScannerScreen()),
      GoRoute(path: '/youtube-summary', builder: (context, state) => const YoutubeSummaryScreen()),
      GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
      GoRoute(path: '/teacher-dashboard', builder: (context, state) => const TeacherDashboardScreen()),
      GoRoute(path: '/features', builder: (context, state) => const FeatureGalleryScreen()),
      GoRoute(path: '/parent-dashboard', builder: (context, state) => const ParentDashboardScreen()),
      GoRoute(path: '/elearning-class', builder: (context, state) => const ClassSelectionScreen()),
      GoRoute(path: '/elearning-subject', builder: (context, state) => const SubjectSelectionScreen()),
      GoRoute(path: '/elearning-topic', builder: (context, state) => const TopicListScreen()),
      GoRoute(path: '/elearning-learning', builder: (context, state) => const TopicLearningScreen()),
      GoRoute(path: '/flashcards', builder: (context, state) => const FlashcardDeckScreen()),
      GoRoute(
        path: '/flashcards/review',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null;
          if (extra == null || extra['deckIndex'] == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Invalid data')),
              body: const Center(
                child: Text(
                  'Missing flashcard data. Please return to dashboard.',
                ),
              ),
            );
          }
          final deckIndex = extra['deckIndex'] is int
              ? extra['deckIndex'] as int
              : int.tryParse(extra['deckIndex'].toString()) ?? 0;
          final deck = extra['deck'] is Map<String, dynamic>
              ? extra['deck'] as Map<String, dynamic>
              : <String, dynamic>{};
          return FlashcardReviewScreen(
            deckIndex: deckIndex,
            deck: deck,
          );
        },
      ),
      GoRoute(path: '/spaced-repetition', builder: (context, state) => const SpacedRepetitionScreen()),
      GoRoute(path: '/ncert-solutions', builder: (context, state) => const NcertSolutionsScreen()),
      GoRoute(path: '/jee-neet-trainer', builder: (context, state) => const JeeNeetTrainerScreen()),
      GoRoute(path: '/ai-study-planner', builder: (context, state) => const AiStudyPlannerScreen()),
      GoRoute(path: '/smart-revision', builder: (context, state) => const SmartRevisionScreen()),
      GoRoute(path: '/mock-test', builder: (context, state) => const MockTestScreen()),
      GoRoute(path: '/offline-exam', builder: (context, state) => const OfflineExamScreen()),
      GoRoute(path: '/quiz-generator', builder: (context, state) => const QuizGeneratorScreen()),
      GoRoute(path: '/multi-lang-tutor', builder: (context, state) => const MultiLangTutorScreen()),
      GoRoute(path: '/math-word-solver', builder: (context, state) => const MathWordSolverScreen()),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => PrivacyPolicyScreen(
          isFirstTime: state.uri.queryParameters['firstTime'] == '1',
        ),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/daily-quiz', builder: (context, state) => const DailyQuizScreen()),
      GoRoute(path: '/search', builder: (context, state) => const AiFeedScreen()),
      GoRoute(path: '/ai-usage', builder: (context, state) => const AiUsageScreen()),
      GoRoute(path: '/attendance', builder: (context, state) => const TeacherAttendanceScreen()),
      GoRoute(
        path: '/attendance/session',
        builder: (context, state) {
          final extra = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null;
          if (extra == null ||
              extra['sessionId'] == null ||
              extra['sectionLabel'] == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Invalid data')),
              body: const Center(
                child: Text(
                  'Missing attendance session data. Please return to dashboard.',
                ),
              ),
            );
          }
          return AttendanceSessionScreen(
            sessionId: extra['sessionId'].toString(),
            sectionLabel: extra['sectionLabel'].toString(),
            subject: extra['subject']?.toString() ?? '',
            initialCode: extra['code']?.toString() ?? '',
            initialCodeTtlSeconds: extra['codeTtlSeconds'] is int
                ? extra['codeTtlSeconds'] as int
                : int.tryParse(extra['codeTtlSeconds']?.toString() ?? '0') ?? 0,
            lat: (extra['lat'] as num?)?.toDouble(),
            lng: (extra['lng'] as num?)?.toDouble(),
            radiusMeters: (extra['radiusMeters'] as num?)?.toInt(),
          );
        },
      ),
      GoRoute(path: '/mark-attendance', builder: (context, state) => const MarkAttendanceScreen()),
    ],
  );
}
