import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:nexus_edu/features/gamification/presentation/screens/leaderboard_screen.dart' as old_leaderboard;
import 'package:nexus_edu/features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import 'package:nexus_edu/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:nexus_edu/features/student_hub/presentation/screens/student_hub_screen.dart';
import 'package:nexus_edu/features/tutor/presentation/screens/essay_roaster_screen.dart';
import 'package:nexus_edu/features/future_tech/presentation/screens/accessibility_hub_screen.dart';
import 'package:nexus_edu/features/study_rooms/presentation/screens/study_rooms_screen.dart';
import 'package:nexus_edu/features/parent/presentation/screens/parent_dashboard_screen.dart';
import 'package:nexus_edu/features/flashcards/presentation/screens/flashcard_deck_screen.dart';
import 'package:nexus_edu/features/flashcards/presentation/screens/flashcard_review_screen.dart';
import 'package:nexus_edu/features/curriculum_agent/presentation/screens/curriculum_agent_screen.dart';
import 'package:nexus_edu/features/spaced_repetition/presentation/screens/spaced_repetition_screen.dart';
import 'package:nexus_edu/features/swarm_tutor/presentation/screens/swarm_tutor_screen.dart';
import 'package:nexus_edu/features/neural_decoding/presentation/screens/neural_decoding_screen.dart';
import 'package:nexus_edu/features/syllabus_universe/presentation/screens/syllabus_universe_screen.dart';
import 'package:nexus_edu/features/genetic_learning/presentation/screens/genetic_learning_screen.dart';
import 'package:nexus_edu/features/temporal_learning/presentation/screens/temporal_learning_screen.dart';
import 'package:nexus_edu/features/exocortex/presentation/screens/exocortex_screen.dart';
import 'package:nexus_edu/features/quantum_circuit/presentation/screens/quantum_circuit_screen.dart';
import 'package:nexus_edu/features/dream_journal/presentation/screens/dream_journal_screen.dart';
import 'package:nexus_edu/features/dau/presentation/screens/dau_screen.dart';
import 'package:nexus_edu/features/singularity_tutor/presentation/screens/singularity_tutor_screen.dart';
import 'package:nexus_edu/features/indian_education_hub/presentation/screens/indian_education_hub_screen.dart';
import 'package:nexus_edu/features/ncert_solutions/presentation/screens/ncert_solutions_screen.dart';
import 'package:nexus_edu/features/jee_neet_trainer/presentation/screens/jee_neet_trainer_screen.dart';
import 'package:nexus_edu/features/exam_prep/presentation/screens/exam_prep_screen.dart';
import 'package:nexus_edu/features/hindi_tutor/presentation/screens/hindi_tutor_screen.dart';
import 'package:nexus_edu/features/handwriting_recognition/presentation/screens/handwriting_recognition_screen.dart';
import 'package:nexus_edu/features/voice_learning/presentation/screens/voice_learning_screen.dart';
import 'package:nexus_edu/features/ai_study_planner/presentation/screens/ai_study_planner_screen.dart';
import 'package:nexus_edu/features/smart_revision/presentation/screens/smart_revision_screen.dart';
import 'package:nexus_edu/features/question_bank/presentation/screens/question_bank_screen.dart';
import 'package:nexus_edu/features/mock_test/presentation/screens/mock_test_screen.dart';
import 'package:nexus_edu/features/study_group/presentation/screens/study_group_screen.dart';
import 'package:nexus_edu/features/peer_teaching/presentation/screens/peer_teaching_screen.dart';
import 'package:nexus_edu/features/learning_analytics/presentation/screens/learning_analytics_screen.dart';
import 'package:nexus_edu/features/school_management/presentation/screens/school_management_screen.dart';
import 'package:nexus_edu/features/scholarship_finder/presentation/screens/scholarship_finder_screen.dart';
import 'package:nexus_edu/features/self_test/presentation/screens/self_test_screen.dart';
import 'package:nexus_edu/features/performance_test/presentation/screens/performance_test_screen.dart';
import 'package:nexus_edu/features/socratic_ai/presentation/screens/socratic_ai_screen.dart';
import 'package:nexus_edu/features/debate_agent/presentation/screens/debate_agent_screen.dart';
import 'package:nexus_edu/features/exam_predictor/presentation/screens/exam_predictor_screen.dart';
import 'package:nexus_edu/features/personalized_tutor/presentation/screens/personalized_tutor_screen.dart';
import 'package:nexus_edu/features/multi_lang_tutor/presentation/screens/multi_lang_tutor_screen.dart';
import 'package:nexus_edu/features/exam_strategy/presentation/screens/exam_strategy_screen.dart';
import 'package:nexus_edu/features/anxiety_coach/presentation/screens/anxiety_coach_screen.dart';
import 'package:nexus_edu/features/accountability_agent/presentation/screens/accountability_agent_screen.dart';
import 'package:nexus_edu/features/career_counselor/presentation/screens/career_counselor_screen.dart';
import 'package:nexus_edu/features/parent_report/presentation/screens/parent_report_screen.dart';
import 'package:nexus_edu/features/ai_textbook/presentation/screens/ai_textbook_screen.dart';
import 'package:nexus_edu/features/question_paper_gen/presentation/screens/question_paper_gen_screen.dart';
import 'package:nexus_edu/features/lab_manual_gen/presentation/screens/lab_manual_gen_screen.dart';
import 'package:nexus_edu/features/story_learning/presentation/screens/story_learning_screen.dart';
import 'package:nexus_edu/features/mnemonic_gen/presentation/screens/mnemonic_gen_screen.dart';
import 'package:nexus_edu/features/audio_notes/presentation/screens/audio_notes_screen.dart';
import 'package:nexus_edu/features/video_script/presentation/screens/video_script_screen.dart';
import 'package:nexus_edu/features/cheat_sheet_gen/presentation/screens/cheat_sheet_gen_screen.dart';
import 'package:nexus_edu/features/mind_map_gen/presentation/screens/mind_map_gen_screen.dart';
import 'package:nexus_edu/features/flashcard_auto_gen/presentation/screens/flashcard_auto_gen_screen.dart';
import 'package:nexus_edu/features/adaptive_quiz/presentation/screens/adaptive_quiz_screen.dart';
import 'package:nexus_edu/features/voice_viva/presentation/screens/voice_viva_screen.dart';
import 'package:nexus_edu/features/essay_evaluator/presentation/screens/essay_evaluator_screen.dart';
import 'package:nexus_edu/features/speed_math/presentation/screens/speed_math_screen.dart';
import 'package:nexus_edu/features/diagram_practice/presentation/screens/diagram_practice_screen.dart';
import 'package:nexus_edu/features/concept_gap_detector/presentation/screens/concept_gap_detector_screen.dart';
import 'package:nexus_edu/features/peer_comparison/presentation/screens/peer_comparison_screen.dart';
import 'package:nexus_edu/features/mock_interview/presentation/screens/mock_interview_screen.dart';
import 'package:nexus_edu/features/spelling_grammar/presentation/screens/spelling_grammar_screen.dart';
import 'package:nexus_edu/features/plagiarism_checker/presentation/screens/plagiarism_checker_screen.dart';
import 'package:nexus_edu/features/learning_dna/presentation/screens/learning_dna_screen.dart';
import 'package:nexus_edu/features/performance_predictor/presentation/screens/performance_predictor_screen.dart';
import 'package:nexus_edu/features/optimal_study_time/presentation/screens/optimal_study_time_screen.dart';
import 'package:nexus_edu/features/burnout_detector/presentation/screens/burnout_detector_screen.dart';
import 'package:nexus_edu/features/topic_mastery/presentation/screens/topic_mastery_screen.dart';
import 'package:nexus_edu/features/forgetting_curve_screen/presentation/screens/forgetting_curve_screen.dart';
import 'package:nexus_edu/features/study_efficiency/presentation/screens/study_efficiency_screen.dart';
import 'package:nexus_edu/features/comparative_analytics/presentation/screens/comparative_analytics_screen.dart';
import 'package:nexus_edu/features/long_term_memory/presentation/screens/long_term_memory_screen.dart';
import 'package:nexus_edu/features/exam_readiness/presentation/screens/exam_readiness_screen.dart';
import 'package:nexus_edu/features/lab_simulator/presentation/screens/lab_simulator_screen.dart';
import 'package:nexus_edu/features/historical_travel/presentation/screens/historical_travel_screen.dart';
import 'package:nexus_edu/features/math_word_solver/presentation/screens/math_word_solver_screen.dart';
import 'package:nexus_edu/features/science_explainer/presentation/screens/science_explainer_screen.dart';
import 'package:nexus_edu/features/writing_coach/presentation/screens/writing_coach_screen.dart';
import 'package:nexus_edu/features/language_exchange/presentation/screens/language_exchange_screen.dart';
import 'package:nexus_edu/features/group_study_mod/presentation/screens/group_study_mod_screen.dart';
import 'package:nexus_edu/features/project_guide/presentation/screens/project_guide_screen.dart';
import 'package:nexus_edu/features/college_app_writer/presentation/screens/college_app_writer_screen.dart';
import 'package:nexus_edu/features/study_abroad/presentation/screens/study_abroad_screen.dart';
import 'package:nexus_edu/features/dashboard/presentation/screens/ai_agents_gallery_screen.dart';
import 'package:nexus_edu/features/privacy_policy/presentation/screens/privacy_policy_screen.dart';
import 'package:nexus_edu/features/settings/presentation/screens/settings_screen.dart';
import 'package:nexus_edu/features/daily_quiz/presentation/screens/daily_quiz_screen.dart';
import 'package:nexus_edu/features/study_timer/presentation/screens/study_timer_screen.dart';
import 'package:nexus_edu/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:nexus_edu/features/mistake_journal/presentation/screens/mistake_journal_screen.dart';
import 'package:nexus_edu/features/flashcards/presentation/screens/flashcard_screen.dart';
import 'package:nexus_edu/features/monetization/presentation/screens/nexus_pro_paywall_screen.dart';
import 'package:nexus_edu/core/services/youtube_discovery_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('Dotenv load skipped: $error');
  }
  await AiService.init();
  await YoutubeDiscoveryService.init();
  await AppSettings.instance.load();
  final prefs = await SharedPreferences.getInstance();
  initialLocation = prefs.getBool('privacy_accepted') ?? false
      ? '/dashboard'
      : '/privacy-policy?firstTime=1';
  runApp(const ProviderScope(child: NexusEduApp()));
}

String initialLocation = '/onboarding';

final _router = GoRouter(
  initialLocation: initialLocation,
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
      builder: (context, state) => const old_leaderboard.LeaderboardScreen(),
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
      path: '/study-rooms',
      builder: (context, state) => const StudyRoomsScreen(),
    ),
    GoRoute(
      path: '/parent-dashboard',
      builder: (context, state) => const ParentDashboardScreen(),
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
    GoRoute(
      path: '/flashcards',
      builder: (context, state) => const FlashcardDeckScreen(),
    ),
    GoRoute(
      path: '/flashcards/review',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return FlashcardReviewScreen(
          deckIndex: extra['deckIndex'] as int,
          deck: extra['deck'] as Map<String, dynamic>,
        );
      },
    ),
    GoRoute(
      path: '/curriculum-agent',
      builder: (context, state) => const CurriculumAgentScreen(),
    ),
    GoRoute(
      path: '/spaced-repetition',
      builder: (context, state) => const SpacedRepetitionScreen(),
    ),
    GoRoute(
      path: '/swarm-tutor',
      builder: (context, state) => const SwarmTutorScreen(),
    ),
    GoRoute(
      path: '/neural-decoding',
      builder: (context, state) => const NeuralDecodingScreen(),
    ),
    GoRoute(
      path: '/syllabus-universe',
      builder: (context, state) => const SyllabusUniverseScreen(),
    ),
    GoRoute(
      path: '/genetic-learning',
      builder: (context, state) => const GeneticLearningScreen(),
    ),
    GoRoute(
      path: '/temporal-learning',
      builder: (context, state) => const TemporalLearningScreen(),
    ),
    GoRoute(
      path: '/exocortex',
      builder: (context, state) => const ExocortexScreen(),
    ),
    GoRoute(
      path: '/quantum-circuit',
      builder: (context, state) => const QuantumCircuitScreen(),
    ),
    GoRoute(
      path: '/dream-journal',
      builder: (context, state) => const DreamJournalScreen(),
    ),
    GoRoute(path: '/dau', builder: (context, state) => const DauScreen()),
    GoRoute(
      path: '/singularity-tutor',
      builder: (context, state) => const SingularityTutorScreen(),
    ),
    GoRoute(
      path: '/india-hub',
      builder: (context, state) => const IndianEducationHubScreen(),
    ),
    GoRoute(
      path: '/ncert-solutions',
      builder: (context, state) => const NcertSolutionsScreen(),
    ),
    GoRoute(
      path: '/jee-neet-trainer',
      builder: (context, state) => const JeeNeetTrainerScreen(),
    ),
    GoRoute(
      path: '/exam-prep',
      builder: (context, state) => const ExamPrepScreen(),
    ),
    GoRoute(
      path: '/hindi-tutor',
      builder: (context, state) => const HindiTutorScreen(),
    ),
    GoRoute(
      path: '/handwriting-recognition',
      builder: (context, state) => const HandwritingRecognitionScreen(),
    ),
    GoRoute(
      path: '/voice-learning',
      builder: (context, state) => const VoiceLearningScreen(),
    ),
    GoRoute(
      path: '/ai-study-planner',
      builder: (context, state) => const AiStudyPlannerScreen(),
    ),
    GoRoute(
      path: '/smart-revision',
      builder: (context, state) => const SmartRevisionScreen(),
    ),
    GoRoute(
      path: '/question-bank',
      builder: (context, state) => const QuestionBankScreen(),
    ),
    GoRoute(
      path: '/mock-test',
      builder: (context, state) => const MockTestScreen(),
    ),
    GoRoute(
      path: '/india-study-group',
      builder: (context, state) => const StudyGroupScreen(),
    ),
    GoRoute(
      path: '/peer-teaching',
      builder: (context, state) => const PeerTeachingScreen(),
    ),
    GoRoute(
      path: '/learning-analytics',
      builder: (context, state) => const LearningAnalyticsScreen(),
    ),
    GoRoute(
      path: '/school-management',
      builder: (context, state) => const SchoolManagementScreen(),
    ),
    GoRoute(
      path: '/scholarship-finder',
      builder: (context, state) => const ScholarshipFinderScreen(),
    ),
    GoRoute(
      path: '/self-test',
      builder: (context, state) => const SelfTestScreen(),
    ),
    GoRoute(
      path: '/performance-test',
      builder: (context, state) => const PerformanceTestScreen(),
    ),
    GoRoute(
      path: '/socratic-ai',
      builder: (context, state) => const SocraticAiScreen(),
    ),
    GoRoute(
      path: '/debate-agent',
      builder: (context, state) => const DebateAgentScreen(),
    ),
    GoRoute(
      path: '/exam-predictor',
      builder: (context, state) => const ExamPredictorScreen(),
    ),
    GoRoute(
      path: '/personalized-tutor',
      builder: (context, state) => const PersonalizedTutorScreen(),
    ),
    GoRoute(
      path: '/multi-lang-tutor',
      builder: (context, state) => const MultiLangTutorScreen(),
    ),
    GoRoute(
      path: '/exam-strategy',
      builder: (context, state) => const ExamStrategyScreen(),
    ),
    GoRoute(
      path: '/anxiety-coach',
      builder: (context, state) => const AnxietyCoachScreen(),
    ),
    GoRoute(
      path: '/accountability-agent',
      builder: (context, state) => const AccountabilityAgentScreen(),
    ),
    GoRoute(
      path: '/career-counselor',
      builder: (context, state) => const CareerCounselorScreen(),
    ),
    GoRoute(
      path: '/parent-report',
      builder: (context, state) => const ParentReportScreen(),
    ),
    GoRoute(
      path: '/ai-textbook',
      builder: (context, state) => const AiTextbookScreen(),
    ),
    GoRoute(
      path: '/question-paper-gen',
      builder: (context, state) => const QuestionPaperGenScreen(),
    ),
    GoRoute(
      path: '/lab-manual-gen',
      builder: (context, state) => const LabManualGenScreen(),
    ),
    GoRoute(
      path: '/story-learning',
      builder: (context, state) => const StoryLearningScreen(),
    ),
    GoRoute(
      path: '/mnemonic-gen',
      builder: (context, state) => const MnemonicGenScreen(),
    ),
    GoRoute(
      path: '/audio-notes',
      builder: (context, state) => const AudioNotesScreen(),
    ),
    GoRoute(
      path: '/video-script',
      builder: (context, state) => const VideoScriptScreen(),
    ),
    GoRoute(
      path: '/cheat-sheet-gen',
      builder: (context, state) => const CheatSheetGenScreen(),
    ),
    GoRoute(
      path: '/mind-map-gen',
      builder: (context, state) => const MindMapGenScreen(),
    ),
    GoRoute(
      path: '/flashcard-auto-gen',
      builder: (context, state) => const FlashcardAutoGenScreen(),
    ),
    GoRoute(
      path: '/adaptive-quiz',
      builder: (context, state) => const AdaptiveQuizScreen(),
    ),
    GoRoute(
      path: '/voice-viva',
      builder: (context, state) => const VoiceVivaScreen(),
    ),
    GoRoute(
      path: '/essay-evaluator',
      builder: (context, state) => const EssayEvaluatorScreen(),
    ),
    GoRoute(
      path: '/speed-math',
      builder: (context, state) => const SpeedMathScreen(),
    ),
    GoRoute(
      path: '/diagram-practice',
      builder: (context, state) => const DiagramPracticeScreen(),
    ),
    GoRoute(
      path: '/concept-gap-detector',
      builder: (context, state) => const ConceptGapDetectorScreen(),
    ),
    GoRoute(
      path: '/peer-comparison',
      builder: (context, state) => const PeerComparisonScreen(),
    ),
    GoRoute(
      path: '/mock-interview',
      builder: (context, state) => const MockInterviewScreen(),
    ),
    GoRoute(
      path: '/spelling-grammar',
      builder: (context, state) => const SpellingGrammarScreen(),
    ),
    GoRoute(
      path: '/plagiarism-checker',
      builder: (context, state) => const PlagiarismCheckerScreen(),
    ),
    GoRoute(
      path: '/learning-dna',
      builder: (context, state) => const LearningDnaScreen(),
    ),
    GoRoute(
      path: '/performance-predictor',
      builder: (context, state) => const PerformancePredictorScreen(),
    ),
    GoRoute(
      path: '/optimal-study-time',
      builder: (context, state) => const OptimalStudyTimeScreen(),
    ),
    GoRoute(
      path: '/burnout-detector',
      builder: (context, state) => const BurnoutDetectorScreen(),
    ),
    GoRoute(
      path: '/topic-mastery',
      builder: (context, state) => const TopicMasteryScreen(),
    ),
    GoRoute(
      path: '/forgetting-curve-agent',
      builder: (context, state) => const ForgettingCurveAgentScreen(),
    ),
    GoRoute(
      path: '/study-efficiency',
      builder: (context, state) => const StudyEfficiencyScreen(),
    ),
    GoRoute(
      path: '/comparative-analytics',
      builder: (context, state) => const ComparativeAnalyticsScreen(),
    ),
    GoRoute(
      path: '/long-term-memory',
      builder: (context, state) => const LongTermMemoryScreen(),
    ),
    GoRoute(
      path: '/exam-readiness',
      builder: (context, state) => const ExamReadinessScreen(),
    ),
    GoRoute(
      path: '/lab-simulator',
      builder: (context, state) => const LabSimulatorScreen(),
    ),
    GoRoute(
      path: '/historical-travel',
      builder: (context, state) => const HistoricalTravelScreen(),
    ),
    GoRoute(
      path: '/math-word-solver',
      builder: (context, state) => const MathWordSolverScreen(),
    ),
    GoRoute(
      path: '/science-explainer',
      builder: (context, state) => const ScienceExplainerScreen(),
    ),
    GoRoute(
      path: '/writing-coach',
      builder: (context, state) => const WritingCoachScreen(),
    ),
    GoRoute(
      path: '/language-exchange',
      builder: (context, state) => const LanguageExchangeScreen(),
    ),
    GoRoute(
      path: '/group-study-mod',
      builder: (context, state) => const GroupStudyModScreen(),
    ),
    GoRoute(
      path: '/project-guide',
      builder: (context, state) => const ProjectGuideScreen(),
    ),
    GoRoute(
      path: '/college-app-writer',
      builder: (context, state) => const CollegeAppWriterScreen(),
    ),
    GoRoute(
      path: '/study-abroad',
      builder: (context, state) => const StudyAbroadScreen(),
    ),
    GoRoute(
      path: '/ai-agents',
      builder: (context, state) => const AiAgentsGalleryScreen(),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => PrivacyPolicyScreen(
        isFirstTime: state.uri.queryParameters['firstTime'] == '1',
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/daily-quiz',
      builder: (context, state) => const DailyQuizScreen(),
    ),
    GoRoute(
      path: '/study-timer',
      builder: (context, state) => const StudyTimerScreen(),
    ),
    GoRoute(
      path: '/mistake-journal',
      builder: (context, state) => const MistakeJournalScreen(),
    ),
    GoRoute(
      path: '/flashcards-new',
      builder: (context, state) => const FlashcardScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const AiFeedScreen(),
    ),
    GoRoute(
      path: '/pro',
      builder: (context, state) => const NexusProPaywallScreen(),
    ),
  ],
);

class NexusEduApp extends StatelessWidget {
  const NexusEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Nexus Edu',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppSettings.instance.themeMode,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
