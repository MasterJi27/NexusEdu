import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 12,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.cyanAccent, Colors.blueAccent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Nexus Edu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '3',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.stars, color: Colors.blueAccent, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '450 XP',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withAlpha(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withAlpha(20),
                    blurRadius: 100,
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
              begin: 0,
              end: 50,
              duration: 3.seconds,
              curve: Curves.easeInOut,
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withAlpha(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withAlpha(15),
                    blurRadius: 80,
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(
              begin: 0,
              end: -30,
              duration: 4.seconds,
              curve: Curves.easeInOut,
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              children: [
                const Text(
                  'Ready to excel?',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your AI Study Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                _buildProBanner(),
                const SizedBox(height: 16),
                _buildStreakAndExamRow(),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    children: [
                      _buildFeaturedCard(
                        context,
                        title: 'AI Smart Notes',
                        subtitle:
                            'Generate & organize study notes instantly with AI.',
                        icon: Icons.auto_awesome,
                        color1: const Color(0xFF8E2DE2),
                        color2: const Color(0xFF4A00E0),
                        route: '/note-editor',
                      ).animate().fade(delay: 100.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: 'Virtual Classroom',
                        subtitle:
                            'Immersive live sessions and interactive learning.',
                        icon: Icons.cast_for_education,
                        color1: const Color(0xFF11998E),
                        color2: const Color(0xFF38EF7D),
                        route: '/live-classes',
                      ).animate().fade(delay: 200.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: 'AR 3D Explorer',
                        subtitle:
                            'Visual Demo: Explore biology and space in mixed reality.',
                        icon: Icons.view_in_ar,
                        color1: const Color(0xFFFF416C),
                        color2: const Color(0xFFFF4B2B),
                        route: '/3d-model',
                      ).animate().fade(delay: 300.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: 'AI Flashcards',
                        subtitle:
                            'Swipeable cards generated from your notes.',
                        icon: Icons.style,
                        color1: const Color(0xFF7B2FF7),
                        color2: const Color(0xFF00DBDE),
                        route: '/flashcards',
                      ).animate().fade(delay: 400.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: 'India Education Hub',
                        subtitle:
                            '60 India-specific features: NCERT, JEE, NEET, Hindi & more.',
                        icon: Icons.flag,
                        color1: const Color(0xFFFF9933),
                        color2: const Color(0xFF138808),
                        route: '/india-hub',
                      ).animate().fade(delay: 500.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: 'Test Yourself',
                        subtitle:
                            'Chapter-wise & syllabus-wise tests. See your performance!',
                        icon: Icons.quiz,
                        color1: const Color(0xFFE91E63),
                        color2: const Color(0xFF9C27B0),
                        route: '/self-test',
                      ).animate().fade(delay: 600.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: 'Performance',
                        subtitle:
                            'Track scores, weak topics, improvement & achievements.',
                        icon: Icons.analytics,
                        color1: const Color(0xFF00BCD4),
                        color2: const Color(0xFF2196F3),
                        route: '/performance-test',
                      ).animate().fade(delay: 700.ms).slideX(begin: 0.2),
                      const SizedBox(width: 16),
                      _buildFeaturedCard(
                        context,
                        title: '50 AI Agents',
                        subtitle:
                            'Final Boss features: Socratic AI, Debate, Exam Predictor & more.',
                        icon: Icons.smart_toy,
                        color1: const Color(0xFFFF6F00),
                        color2: const Color(0xFFFFD600),
                        route: '/ai-agents',
                      ).animate().fade(delay: 800.ms).slideX(begin: 0.2),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Next-Gen Features',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMiniFeatureCard(context, title: 'Neural Decoding', subtitle: 'Silent thought-to-learning', icon: Icons.psychology, color: Colors.purpleAccent, route: '/neural-decoding'),
                    _buildMiniFeatureCard(context, title: 'Syllabus Universe', subtitle: 'Playable 3D knowledge worlds', icon: Icons.public, color: Colors.tealAccent, route: '/syllabus-universe'),
                    _buildMiniFeatureCard(context, title: 'Genetic Learning', subtitle: 'DNA-personalized path', icon: Icons.biotech, color: Colors.pinkAccent, route: '/genetic-learning'),
                    _buildMiniFeatureCard(context, title: 'Temporal Learning', subtitle: '6x time dilation sessions', icon: Icons.timer, color: Colors.orangeAccent, route: '/temporal-learning'),
                    _buildMiniFeatureCard(context, title: 'Exocortex', subtitle: 'Second brain implant', icon: Icons.headphones, color: Colors.blueAccent, route: '/exocortex'),
                    _buildMiniFeatureCard(context, title: 'Quantum Circuit', subtitle: 'Build quantum algorithms', icon: Icons.science, color: Colors.cyanAccent, route: '/quantum-circuit'),
                    _buildMiniFeatureCard(context, title: 'Dream Journal', subtitle: 'Lucid dream tutor', icon: Icons.bedtime, color: Colors.indigoAccent, route: '/dream-journal'),
                    _buildMiniFeatureCard(context, title: 'DA University', subtitle: 'On-chain degrees & DAO', icon: Icons.account_balance, color: Colors.amberAccent, route: '/dau'),
                    _buildMiniFeatureCard(context, title: 'Singularity Tutor', subtitle: 'IQ 100 → 10,000', icon: Icons.auto_awesome, color: Color(0xFFFFD700), route: '/singularity-tutor'),
                    _buildMiniFeatureCard(context, title: 'Self-Assembling AI', subtitle: 'Auto-generates curriculum', icon: Icons.radar, color: Colors.deepPurpleAccent, route: '/curriculum-agent'),
                    _buildMiniFeatureCard(context, title: '4D Spaced Repetition', subtitle: 'Time x Context x Mood', icon: Icons.all_inclusive, color: Colors.cyanAccent, route: '/spaced-repetition'),
                    _buildMiniFeatureCard(context, title: 'Swarm AGI Tutor', subtitle: '10k agents compete', icon: Icons.groups_3, color: Colors.amberAccent, route: '/swarm-tutor'),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Smart Learning',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildGridItem(
                      context,
                      Icons.school,
                      'My Syllabus',
                      Colors.amberAccent,
                      '/elearning-class',
                    ).animate().fade(delay: 360.ms),
                    _buildGridItem(
                      context,
                      Icons.smart_display,
                      'Learning Shorts',
                      Colors.redAccent,
                      '/feed',
                    ).animate().fade(delay: 380.ms),
                    _buildGridItem(
                      context,
                      Icons.document_scanner,
                      'AI Vision Scanner',
                      Colors.tealAccent,
                      '/scanner',
                    ).animate().fade(delay: 400.ms),
                    _buildGridItem(
                      context,
                      Icons.local_fire_department,
                      'Practice Quiz',
                      Colors.deepOrange,
                      '/quiz',
                    ).animate().fade(delay: 450.ms),
                    _buildGridItem(
                      context,
                      Icons.mic,
                      'Voice Tutor',
                      Colors.purpleAccent,
                      '/tutor',
                    ).animate().fade(delay: 500.ms),
                    _buildGridItem(
                      context,
                      Icons.smart_display,
                      'YT Summary',
                      Colors.redAccent,
                      '/youtube-summary',
                    ).animate().fade(delay: 550.ms),
                    _buildGridItem(
                      context,
                      Icons.account_tree,
                      'AI Roadmap',
                      Colors.blueAccent,
                      '/roadmap',
                    ).animate().fade(delay: 600.ms),
                    _buildGridItem(
                      context,
                      Icons.timer,
                      'Focus Room',
                      Colors.amberAccent,
                      '/focus',
                    ).animate().fade(delay: 650.ms),
                    _buildGridItem(
                      context,
                      Icons.groups,
                      'Study Rooms',
                      Colors.indigoAccent,
                      '/study-groups',
                    ).animate().fade(delay: 700.ms),
                    _buildGridItem(
                      context,
                      Icons.style,
                      'Flashcards',
                      Colors.deepPurpleAccent,
                      '/flashcards',
                    ).animate().fade(delay: 750.ms),
                  ],
                ),
                if (_userRole == 'Parent' || _userRole == 'Teacher') ...[
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_userRole == 'Parent')
                    _buildQuickAccessCard(
                      context,
                      icon: Icons.family_restroom,
                      title: 'Parent Dashboard',
                      subtitle: 'Monitor your child\'s progress',
                      color: Colors.tealAccent,
                      route: '/parent-dashboard',
                    ),
                  if (_userRole == 'Teacher')
                    _buildQuickAccessCard(
                      context,
                      icon: Icons.co_present,
                      title: 'Teacher Dashboard',
                      subtitle: 'Manage classes & students',
                      color: Colors.orangeAccent,
                      route: '/teacher-dashboard',
                    ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProBanner() {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(0.05)
        ..rotateY(-0.02),
      alignment: FractionalOffset.center,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.amberAccent, Colors.deepOrangeAccent],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withAlpha(30),
              blurRadius: 0,
              offset: const Offset(1, 1),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Nexus Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Unlimited AI Doubts & Live Classes',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                'Get Pro',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ).animate().fade().scale(),
    );
  }

  Widget _buildStreakAndExamRow() {
    final settings = AppSettings.instance;
    final streak = settings.streak;
    final examDate = settings.examDate;
    final examName = settings.examName;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.withAlpha(40), Colors.deepOrange.withAlpha(20)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streak Day Streak', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      streak >= 7 ? 'Amazing!' : 'Keep going!',
                      style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (examDate != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purpleAccent.withAlpha(30), Colors.deepPurple.withAlpha(20)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.purpleAccent.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event, color: Colors.purpleAccent, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(examName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${examDate.difference(DateTime.now()).inDays}d left',
                        style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ).animate().fade(delay: 50.ms).slideY(begin: 0.1);
  }

  Widget _buildFeaturedCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color1,
    required Color color2,
    required String route,
  }) {
    double tiltX = 0;
    double tiltY = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onHover: (event) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final center = box.size.center(Offset.zero);
            setState(() {
              tiltX = (event.localPosition.dy - center.dy) / 2000;
              tiltY = (center.dx - event.localPosition.dx) / 2000;
            });
          },
          onExit: (_) => setState(() {
            tiltX = 0;
            tiltY = 0;
          }),
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(tiltX)
              ..rotateY(tiltY - 0.03),
            alignment: FractionalOffset.center,
            child: Hero(
              tag: 'feature-$title',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(route);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color1, color2],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: color1.withAlpha(50),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.white.withAlpha(30),
                          blurRadius: 0,
                          offset: const Offset(1, 1),
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const Spacer(),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    String route,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(route);
      },
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(route);
      },
        child: Container(
          padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(150))),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(route);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(60), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withAlpha(150), size: 18),
          ],
        ),
      ),
    ).animate().fade().slideX(begin: 0.1);
  }
}
