import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/subject_progress_service.dart';
import 'package:nexus_edu/core/widgets/animated_background.dart';

const Color _bg = Color(0xFF0F1115);
const Color _accent = Color(0xFF7C5CFF);
const Color _success = Color(0xFF55D6A4);
const Color _warning = Color(0xFFFFC857);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  final ScrollController _scrollController = ScrollController(keepScrollOffset: false);
  final GamificationService _gamification = GamificationService();
  final SubjectProgressService _subjectProgress = SubjectProgressService();
  String? _selectedClass;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    await _gamification.load();
    await _subjectProgress.load();
    if (!mounted) return;
    setState(() => _selectedClass = selectedClass);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final daysLeft = settings.examDate?.difference(DateTime.now()).inDays;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: _accent.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: _accent, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'NexusEdu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          _HeaderMetric(
            icon: Icons.local_fire_department,
            label: '${_gamification.streak}',
            color: _warning,
            onTap: () => context.push('/leaderboard'),
          ),
          const SizedBox(width: 8),
          _HeaderMetric(
            icon: Icons.stars_rounded,
            label: '${_gamification.xp} XP',
            color: _accent,
            onTap: () => context.push('/leaderboard'),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          ),
        ],
      ),
      body: AnimatedBackground(
        enableParticles: true,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _SearchBar(
              onChanged: (v) => setState(() => _searchQuery = v),
              onTap: () => context.push('/search'),
            ),
            const SizedBox(height: 14),
            _HeroPanel(
              selectedClass: _selectedClass,
              examName: settings.examName,
              daysLeft: daysLeft,
              onClassTap: () => context.push('/elearning-class'),
              gamification: _gamification,
            ),
            const SizedBox(height: 14),
            _ExamCountdown(
              examName: settings.examName,
              daysLeft: daysLeft,
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Continue Learning',
              actionLabel: 'Class',
              onAction: () => context.push('/elearning-class'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PrimaryActionCard(
                    icon: Icons.auto_stories_outlined,
                    title: 'My Syllabus',
                    subtitle: _selectedClass ?? 'Choose class',
                    color: _accent,
                    onTap: () => context.push('/elearning-class'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PrimaryActionCard(
                    icon: Icons.smart_display_outlined,
                    title: 'Shorts',
                    subtitle: 'Topic-wise videos',
                    color: const Color(0xFFFF6B6B),
                    onTap: () => context.go('/feed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionHeader(title: 'Your Subjects', actionLabel: 'All', onAction: () => context.push('/elearning-class')),
            const SizedBox(height: 10),
            _SubjectProgressSection(subjectProgress: _subjectProgress),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Quick Actions'),
            const SizedBox(height: 10),
            _QuickActionsGrid(
              items: [
                _HomeAction('AI Tutor', 'Ask doubts clearly', Icons.smart_toy_outlined, '/tutor', _accent),
                _HomeAction('Daily Quiz', '10 questions, earn XP', Icons.quiz_outlined, '/daily-quiz', const Color(0xFFFF8A65)),
                _HomeAction('Study Timer', 'Pomodoro focus', Icons.timer_outlined, '/study-timer', _success),
                _HomeAction('Flashcards', 'Active recall practice', Icons.style_outlined, '/flashcards', const Color(0xFF64B5F6)),
                _HomeAction('Mistake Journal', 'Review errors', Icons.error_outline, '/mistake-journal', const Color(0xFFFF6B6B)),
                _HomeAction('Smart Notes', 'Generate and revise', Icons.note_alt_outlined, '/notes', _warning),
              ],
              onTap: _openRoute,
            ),
            const SizedBox(height: 22),
            _SectionHeader(title: 'Leaderboard', actionLabel: 'See All', onAction: () => context.push('/leaderboard')),
            const SizedBox(height: 10),
            _LeaderboardPreview(gamification: _gamification),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Exam & Progress'),
            const SizedBox(height: 10),
            _ActionGrid(
              items: [
                _HomeAction('Mock Test', 'Exam-like practice', Icons.assignment_outlined, '/mock-test', const Color(0xFF64B5F6)),
                _HomeAction('Performance', 'Weak topics and scores', Icons.insights_outlined, '/performance-test', _success),
                _HomeAction('Book Scanner', 'Scan textbook pages', Icons.document_scanner_outlined, '/scanner', _success),
                _HomeAction('Study Planner', 'Plan today', Icons.event_note_outlined, '/ai-study-planner', _warning),
              ],
              onTap: _openRoute,
            ),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'More'),
            const SizedBox(height: 10),
            _MoreList(
              items: [
                _HomeAction('AI Tools Library', 'All advanced agents in one place', Icons.auto_awesome_outlined, '/ai-agents', _accent),
                _HomeAction('India Education Hub', 'NCERT, JEE, NEET and Hindi tools', Icons.flag_outlined, '/india-hub', const Color(0xFFFFB74D)),
                _HomeAction('Settings', 'Appearance, privacy and study prefs', Icons.tune_outlined, '/settings', _success),
              ],
              onTap: _openRoute,
            ),
          ],
        ),
      ),
    );
  }

  void _openRoute(String route) {
    HapticFeedback.lightImpact();
    if (route == '/feed' || route == '/notes' || route == '/tutor') {
      context.go(route);
      return;
    }
    context.push(route);
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged, required this.onTap});

  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF171A21),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2F3A)),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.white38, size: 20),
            SizedBox(width: 10),
            Text(
              'Search topics, quizzes, doubts...',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.selectedClass,
    required this.examName,
    required this.daysLeft,
    required this.onClassTap,
    required this.gamification,
  });

  final String? selectedClass;
  final String examName;
  final int? daysLeft;
  final VoidCallback onClassTap;
  final GamificationService gamification;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2F3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedClass == null ? 'Ready to study?' : 'Ready, $selectedClass learner?',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your study dashboard',
                      style: TextStyle(color: Colors.white, fontSize: 24, height: 1.1, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lv.${gamification.level}',
                  style: TextStyle(color: _accent, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E232D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level ${gamification.level} — ${gamification.levelTitle}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${gamification.xpProgress}/${gamification.xpForNextLevel} XP',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: gamification.levelProgress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(_accent),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallStatus(
                  icon: Icons.school_outlined,
                  title: selectedClass ?? 'No class selected',
                  subtitle: selectedClass == null ? 'Tap to set' : 'Syllabus active',
                  color: _accent,
                  onTap: onClassTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStatus(
                  icon: Icons.event_available_outlined,
                  title: daysLeft == null ? 'Exam target' : '$daysLeft days left',
                  subtitle: daysLeft == null ? 'Set in Profile' : examName,
                  color: const Color(0xFFFFC857),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamCountdown extends StatelessWidget {
  const _ExamCountdown({required this.examName, required this.daysLeft});

  final String examName;
  final int? daysLeft;

  @override
  Widget build(BuildContext context) {
    if (daysLeft == null) return const SizedBox.shrink();
    final color = daysLeft! <= 30 ? const Color(0xFFFF6B6B) : daysLeft! <= 90 ? const Color(0xFFFFC857) : _success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(examName, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$daysLeft days remaining', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Countdown', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SubjectProgressSection extends StatelessWidget {
  const _SubjectProgressSection({required this.subjectProgress});

  final SubjectProgressService subjectProgress;

  @override
  Widget build(BuildContext context) {
    final subjects = subjectProgress.subjects.take(4).toList();
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final s = subjects[index];
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF171A21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2F3A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.icon, style: const TextStyle(fontSize: 20)),
                    const Spacer(),
                    Text(
                      '${(s.progress * 100).round()}%',
                      style: TextStyle(
                        color: s.progress >= 0.7 ? _success : s.progress >= 0.4 ? _warning : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${s.completedChapters}/${s.totalChapters} chapters',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: s.progress,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                      s.progress >= 0.7 ? _success : s.progress >= 0.4 ? _warning : _accent,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.items, required this.onTap});

  final List<_HomeAction> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => onTap(item.route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF171A21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2F3A)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: item.color, size: 26),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview({required this.gamification});

  final GamificationService gamification;

  @override
  Widget build(BuildContext context) {
    final top3 = GamificationService.leaderboard.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2F3A)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < top3.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      i == 0 ? '🥇' : i == 1 ? '🥈' : '🥉',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: top3[i]['isUser'] == true ? _accent : Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (top3[i]['name'] as String)[0],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      top3[i]['name'],
                      style: TextStyle(
                        color: top3[i]['isUser'] == true ? _accent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${top3[i]['xp']} XP',
                    style: TextStyle(
                      color: top3[i]['isUser'] == true ? _accent : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _SmallStatus extends StatelessWidget {
  const _SmallStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E232D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2F3A)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171A21),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2F3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 22),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.items, required this.onTap});

  final List<_HomeAction> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => onTap(item.route),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF171A21),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2F3A)),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: item.color, size: 25),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MoreList extends StatelessWidget {
  const _MoreList({required this.items, required this.onTap});

  final List<_HomeAction> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => onTap(item.route),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF2A2F3A))),
              tileColor: const Color(0xFF171A21),
              leading: Icon(item.icon, color: item.color),
              title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              subtitle: Text(item.subtitle, style: const TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
          ),
      ],
    );
  }
}

class _HomeAction {
  const _HomeAction(this.title, this.subtitle, this.icon, this.route, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
}
