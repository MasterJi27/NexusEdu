import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IndianEducationHubScreen extends StatefulWidget {
  const IndianEducationHubScreen({super.key});

  @override
  State<IndianEducationHubScreen> createState() =>
      _IndianEducationHubScreenState();
}

class _IndianEducationHubScreenState extends State<IndianEducationHubScreen> {
  Set<String> _favorites = {};
  final Map<String, bool> _expandedSections = {
    'ai_learning': true,
    'exam_prep': true,
    'content': true,
    'social': true,
    'analytics': true,
    'business': true,
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('india_hub_favorites') ?? [];
    setState(() => _favorites = saved.toSet());
  }

  Future<void> _toggleFavorite(String featureId) async {
    setState(() {
      if (_favorites.contains(featureId)) {
        _favorites.remove(featureId);
      } else {
        _favorites.add(featureId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('india_hub_favorites', _favorites.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🇮🇳', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'India Education Hub',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            const SizedBox(height: 20),
            _buildSection(
              'ai_learning',
              'AI-Powered Learning',
              Icons.auto_awesome,
              Colors.deepPurpleAccent,
              _aiLearningFeatures,
            ),
            _buildSection(
              'exam_prep',
              'Exam Preparation',
              Icons.quiz,
              Colors.orangeAccent,
              _examPrepFeatures,
            ),
            _buildSection(
              'content',
              'Content Creation',
              Icons.edit_note,
              Colors.tealAccent,
              _contentFeatures,
            ),
            _buildSection(
              'social',
              'Social & Collaborative',
              Icons.group,
              Colors.pinkAccent,
              _socialFeatures,
            ),
            _buildSection(
              'analytics',
              'Advanced Analytics',
              Icons.analytics,
              Colors.cyanAccent,
              _analyticsFeatures,
            ),
            _buildSection(
              'business',
              'Business & Monetization',
              Icons.business_center,
              Colors.amberAccent,
              _businessFeatures,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF9933),
            Color(0xFFFFFFFF),
            Color(0xFF138808),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F13).withAlpha(220),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flag,
                color: Colors.deepPurpleAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Made for Indian Students',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '60+ India-specific features • Multi-language • Board-aligned',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: -0.06);
  }

  Widget _buildSection(
    String sectionId,
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> features,
  ) {
    final isExpanded = _expandedSections[sectionId] ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[sectionId] = !isExpanded;
                });
              },
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${features.length}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    final feature = features[index];
                    return _buildFeatureCard(feature, color);
                  },
                ),
              ),
          ],
        ),
      ),
    ).animate().fade(delay: Duration(milliseconds: (50 * _allFeatures.indexOf(features[0])).clamp(0, 400)));
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, Color sectionColor) {
    final isFav = _favorites.contains(feature['id']);
    return GestureDetector(
      onTap: () => context.push(feature['route']),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFav
                ? Colors.amberAccent.withAlpha(80)
                : Colors.white.withAlpha(15),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  feature['icon'] as IconData,
                  color: sectionColor,
                  size: 26,
                ),
                if (feature['isNew'] == true)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              feature['title'] as String,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(200),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              feature['desc'] as String,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withAlpha(100),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _toggleFavorite(feature['id'] as String),
              child: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amberAccent : Colors.white38,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _allFeatures => [
        ..._aiLearningFeatures,
        ..._examPrepFeatures,
        ..._contentFeatures,
        ..._socialFeatures,
        ..._analyticsFeatures,
        ..._businessFeatures,
      ];

  static final List<Map<String, dynamic>> _aiLearningFeatures = [
    {
      'id': 'ai_tutor_multi_lang',
      'title': 'AI Tutor Hindi/Regional',
      'desc': 'AI tutor in Indian languages',
      'icon': Icons.record_voice_over,
      'route': '/hindi-tutor',
      'isNew': true,
    },
    {
      'id': 'handwriting_scanner',
      'title': 'Handwriting Scanner',
      'desc': 'Scan handwritten notes',
      'icon': Icons.draw,
      'route': '/handwriting-recognition',
      'isNew': true,
    },
    {
      'id': 'voice_learning',
      'title': 'Voice Learning',
      'desc': 'Learn by speaking',
      'icon': Icons.mic,
      'route': '/voice-learning',
      'isNew': true,
    },
    {
      'id': 'ai_study_planner',
      'title': 'AI Study Planner',
      'desc': 'Personalized schedule',
      'icon': Icons.calendar_month,
      'route': '/ai-study-planner',
      'isNew': false,
    },
    {
      'id': 'smart_revision',
      'title': 'Smart Revision',
      'desc': 'Spaced repetition system',
      'icon': Icons.replay,
      'route': '/smart-revision',
      'isNew': false,
    },
    {
      'id': 'concept_gap_filler',
      'title': 'Concept Gap Filler',
      'desc': 'NCERT solutions on demand',
      'icon': Icons.power,
      'route': '/ncert-solutions',
      'isNew': false,
    },
    {
      'id': 'learning_speed',
      'title': 'Learning Speed Analyzer',
      'desc': 'Track your learning pace',
      'icon': Icons.speed,
      'route': '/learning-analytics',
      'isNew': true,
    },
    {
      'id': 'ai_doubt_resolver',
      'title': 'AI Doubt Resolver',
      'desc': 'Get instant doubt help',
      'icon': Icons.help_outline,
      'route': '/tutor',
      'isNew': false,
    },
    {
      'id': 'study_optimizer',
      'title': 'Study Session Optimizer',
      'desc': 'Optimize study sessions',
      'icon': Icons.tune,
      'route': '/ai-study-planner',
      'isNew': true,
    },
    {
      'id': 'ai_concept_mapper',
      'title': 'AI Concept Mapper',
      'desc': 'Map concept relationships',
      'icon': Icons.account_tree,
      'route': '/learning-analytics',
      'isNew': true,
    },
  ];

  static final List<Map<String, dynamic>> _examPrepFeatures = [
    {
      'id': 'predicted_questions',
      'title': 'Predicted Questions',
      'desc': 'AI-predicted exam questions',
      'icon': Icons.auto_awesome,
      'route': '/exam-prep',
      'isNew': true,
    },
    {
      'id': 'previous_year',
      'title': 'Previous Year Analysis',
      'desc': 'Analyze past papers',
      'icon': Icons.analytics,
      'route': '/exam-prep',
      'isNew': false,
    },
    {
      'id': 'mock_test',
      'title': 'Mock Test',
      'desc': 'Full-length practice tests',
      'icon': Icons.timer,
      'route': '/mock-test',
      'isNew': false,
    },
    {
      'id': 'speed_accuracy',
      'title': 'Speed vs Accuracy',
      'desc': 'Balance speed & accuracy',
      'icon': Icons.speed,
      'route': '/exam-prep',
      'isNew': true,
    },
    {
      'id': 'time_management',
      'title': 'Time Management',
      'desc': 'Exam time strategies',
      'icon': Icons.hourglass_top,
      'route': '/exam-prep',
      'isNew': false,
    },
    {
      'id': 'negative_marking',
      'title': 'Negative Marking Calc',
      'desc': 'Calculate marking impact',
      'icon': Icons.calculate,
      'route': '/exam-prep',
      'isNew': true,
    },
    {
      'id': 'exam_simulator',
      'title': 'Exam Day Simulator',
      'desc': 'Simulate exam conditions',
      'icon': Icons.school,
      'route': '/mock-test',
      'isNew': true,
    },
    {
      'id': 'last_minute',
      'title': 'Last Minute Revision',
      'desc': 'Quick revision tools',
      'icon': Icons.flash_on,
      'route': '/smart-revision',
      'isNew': false,
    },
    {
      'id': 'formula_recall',
      'title': 'Formula Recall',
      'desc': 'Formula practice sheets',
      'icon': Icons.functions,
      'route': '/smart-revision',
      'isNew': false,
    },
    {
      'id': 'diagram_practice',
      'title': 'Diagram Practice',
      'desc': 'Practice diagram questions',
      'icon': Icons.draw,
      'route': '/ncert-solutions',
      'isNew': true,
    },
  ];

  static final List<Map<String, dynamic>> _contentFeatures = [
    {
      'id': 'textbook_writer',
      'title': 'AI Textbook Writer',
      'desc': 'Generate textbook content',
      'icon': Icons.menu_book,
      'route': '/question-bank',
      'isNew': true,
    },
    {
      'id': 'question_bank',
      'title': 'Question Bank',
      'desc': 'Huge question repository',
      'icon': Icons.question_answer,
      'route': '/question-bank',
      'isNew': false,
    },
    {
      'id': 'study_material',
      'title': 'Study Material Gen',
      'desc': 'Generate study materials',
      'icon': Icons.article,
      'route': '/ncert-solutions',
      'isNew': true,
    },
    {
      'id': 'ncert_solutions',
      'title': 'NCERT Solutions',
      'desc': 'Chapter-wise solutions',
      'icon': Icons.check_circle,
      'route': '/ncert-solutions',
      'isNew': false,
    },
    {
      'id': 'rd_sharma',
      'title': 'RD Sharma Solutions',
      'desc': 'Math solutions guide',
      'icon': Icons.calculate,
      'route': '/ncert-solutions',
      'isNew': false,
    },
    {
      'id': 'lab_manual',
      'title': 'Lab Manual',
      'desc': 'Science lab experiments',
      'icon': Icons.science,
      'route': '/question-bank',
      'isNew': true,
    },
    {
      'id': 'assignment_creator',
      'title': 'Assignment Creator',
      'desc': 'Create assignments easily',
      'icon': Icons.assignment,
      'route': '/question-bank',
      'isNew': true,
    },
  ];

  static final List<Map<String, dynamic>> _socialFeatures = [
    {
      'id': 'study_group_matcher',
      'title': 'Study Group Matcher',
      'desc': 'Find study groups',
      'icon': Icons.groups,
      'route': '/study-group',
      'isNew': true,
    },
    {
      'id': 'virtual_study_room',
      'title': 'Virtual Study Room',
      'desc': 'Study together online',
      'icon': Icons.meeting_room,
      'route': '/study-group',
      'isNew': true,
    },
    {
      'id': 'peer_teaching',
      'title': 'Peer Teaching',
      'desc': 'Teach & learn from peers',
      'icon': Icons.handshake,
      'route': '/peer-teaching',
      'isNew': false,
    },
    {
      'id': 'class_leaderboard',
      'title': 'Class Leaderboard',
      'desc': 'Compete with classmates',
      'icon': Icons.leaderboard,
      'route': '/leaderboard',
      'isNew': false,
    },
    {
      'id': 'study_buddy_finder',
      'title': 'Study Buddy Finder',
      'desc': 'Find study partners',
      'icon': Icons.person_add,
      'route': '/study-group',
      'isNew': true,
    },
  ];

  static final List<Map<String, dynamic>> _analyticsFeatures = [
    {
      'id': 'learning_dna',
      'title': 'Learning DNA Report',
      'desc': 'Your learning profile',
      'icon': Icons.science,
      'route': '/learning-analytics',
      'isNew': true,
    },
    {
      'id': 'predicted_rank',
      'title': 'Predicted Rank',
      'desc': 'AI rank prediction',
      'icon': Icons.emoji_events,
      'route': '/learning-analytics',
      'isNew': true,
    },
    {
      'id': 'weakness_heatmap',
      'title': 'Weakness Heatmap',
      'desc': 'Visualize weak areas',
      'icon': Icons.map,
      'route': '/learning-analytics',
      'isNew': true,
    },
    {
      'id': 'performance_pred',
      'title': 'Performance Prediction',
      'desc': 'Predict exam performance',
      'icon': Icons.trending_up,
      'route': '/learning-analytics',
      'isNew': false,
    },
    {
      'id': 'study_efficiency',
      'title': 'Study Efficiency',
      'desc': 'Measure study efficiency',
      'icon': Icons.electric_meter,
      'route': '/learning-analytics',
      'isNew': false,
    },
  ];

  static final List<Map<String, dynamic>> _businessFeatures = [
    {
      'id': 'school_management',
      'title': 'School Management',
      'desc': 'Manage school operations',
      'icon': Icons.business,
      'route': '/school-management',
      'isNew': true,
    },
    {
      'id': 'coaching_platform',
      'title': 'Coaching Platform',
      'desc': 'Run coaching classes',
      'icon': Icons.campaign,
      'route': '/school-management',
      'isNew': true,
    },
    {
      'id': 'scholarship_finder',
      'title': 'Scholarship Finder',
      'desc': 'Find scholarships easily',
      'icon': Icons.card_giftcard,
      'route': '/scholarship-finder',
      'isNew': false,
    },
    {
      'id': 'college_admission',
      'title': 'College Admission',
      'desc': 'Admission guidance',
      'icon': Icons.school,
      'route': '/scholarship-finder',
      'isNew': false,
    },
  ];
}
