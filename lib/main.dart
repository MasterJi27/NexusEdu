import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
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
import 'package:nexus_edu/features/practice/presentation/screens/code_sandbox_screen.dart';
import 'package:nexus_edu/features/practice/presentation/screens/quiz_screen.dart';
import 'package:nexus_edu/features/practice/presentation/screens/socratic_solver_screen.dart';
import 'package:nexus_edu/features/dashboard/presentation/screens/model_viewer_screen.dart';
import 'package:nexus_edu/features/dashboard/presentation/screens/forgetting_curve_screen.dart';
import 'package:nexus_edu/features/live/presentation/screens/live_classes_screen.dart';
import 'package:nexus_edu/features/community/presentation/screens/study_groups_screen.dart';
import 'package:nexus_edu/features/roadmap/presentation/screens/roadmap_generator_screen.dart';
import 'package:nexus_edu/features/scanner/presentation/screens/youtube_summary_screen.dart';
import 'package:nexus_edu/features/gamification/presentation/screens/leaderboard_screen.dart';
import 'package:nexus_edu/features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import 'package:nexus_edu/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:nexus_edu/features/student_hub/presentation/screens/student_hub_screen.dart';
import 'package:nexus_edu/features/tutor/presentation/screens/essay_roaster_screen.dart';
import 'package:nexus_edu/features/future_tech/presentation/screens/accessibility_hub_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('Dotenv load skipped: $error');
  }
  await AiService.init();
  runApp(const ProviderScope(child: NexusEduApp()));
}

final _router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainNavigationScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/feed',
          builder: (context, state) => const AiFeedScreen(),
        ),
        GoRoute(
          path: '/tutor',
          builder: (context, state) => const TutorChatScreen(),
        ),
        GoRoute(
          path: '/notes',
          builder: (context, state) => const NotesScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/note-editor',
      builder: (context, state) => const SmartNoteEditorScreen(),
    ),
    GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const AiScannerScreen(),
    ),
    GoRoute(path: '/quiz', builder: (context, state) => const QuizScreen()),
    GoRoute(
      path: '/socratic-solver',
      builder: (context, state) => const SocraticSolverScreen(),
    ),
    GoRoute(
      path: '/essay-roaster',
      builder: (context, state) => const EssayRoasterScreen(),
    ),
    GoRoute(
      path: '/forgetting-curve',
      builder: (context, state) => const ForgettingCurveScreen(),
    ),
    GoRoute(
      path: '/student-hub',
      builder: (context, state) => const StudentHubScreen(),
    ),
    GoRoute(
      path: '/code-sandbox',
      builder: (context, state) => const CodeSandboxScreen(),
    ),
    GoRoute(
      path: '/accessibility-hub',
      builder: (context, state) => const AccessibilityHubScreen(),
    ),
    GoRoute(
      path: '/3d-model',
      builder: (context, state) => const InteractiveModelScreen(),
    ),
    GoRoute(
      path: '/live-classes',
      builder: (context, state) => const LiveClassesScreen(),
    ),
    GoRoute(
      path: '/study-groups',
      builder: (context, state) => const StudyGroupsScreen(),
    ),
    GoRoute(
      path: '/roadmap',
      builder: (context, state) => const RoadmapGeneratorScreen(),
    ),
    GoRoute(
      path: '/youtube-summary',
      builder: (context, state) => const YoutubeSummaryScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: '/teacher-dashboard',
      builder: (context, state) => const TeacherDashboardScreen(),
    ),
    GoRoute(
      path: '/features',
      builder: (context, state) => const FeatureGalleryScreen(),
    ),
    GoRoute(
      path: '/elearning-class',
      builder: (context, state) => const ClassSelectionScreen(),
    ),
    GoRoute(
      path: '/elearning-subject',
      builder: (context, state) => const SubjectSelectionScreen(),
    ),
    GoRoute(
      path: '/elearning-topic',
      builder: (context, state) => const TopicListScreen(),
    ),
    GoRoute(
      path: '/elearning-learning',
      builder: (context, state) => const TopicLearningScreen(),
    ),
  ],
);

class NexusEduApp extends StatelessWidget {
  const NexusEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nexus Edu',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
