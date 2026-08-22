import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/subject_progress_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';

/// The Learn tab home. Rebuilt on the token system: no continuous background
/// animation (the previous `AnimatedBackground` repainted three blurred glows
/// and fifteen particles at 60fps behind this entire screen, forever), and no
/// invented leaderboard — the old preview pinned "You" at a hardcoded rank 3
/// with 2,450 XP regardless of the signed-in user's actual data. See
/// `PRODUCT.md`: a number that cannot be traced to the user's own activity
/// must not be presented as fact.
///
/// Ordering is the daily flow, not a menu: the plan is first ("do these three
/// today"), then search, then reference material (syllabus, subjects, tools).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  final GamificationService _gamification = GamificationService();
  final SubjectProgressService _subjectProgress = SubjectProgressService();
  String? _selectedClass;

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

  void _openRoute(String route) {
    HapticFeedback.lightImpact();
    if (route == '/feed' || route == '/notes' || route == '/tutor') {
      context.go(route);
      return;
    }
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = AppSettings.instance;
    final daysLeft = settings.examDate?.difference(DateTime.now()).inDays;

    return NexusScreen(
      title: 'Nexus Edu',
      titleWidget: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Icons.school_outlined, color: t.primary, size: 20),
          ),
          const SizedBox(width: AppSpace.xs),
          const Expanded(
            child: const Text(
              'Nexus Edu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        _HeaderMetric(
          icon: Icons.local_fire_department_outlined,
          label: '${_gamification.streak}',
          onTap: () => context.push('/leaderboard'),
        ),
        const SizedBox(width: AppSpace.xs),
        _HeaderMetric(
          icon: Icons.stars_outlined,
          label: '${_gamification.xp} XP',
          onTap: () => context.push('/leaderboard'),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          if (!SecureApiService().isLoggedIn) ...[
            _GuestBanner(onSignIn: () => context.go('/login')),
            const SizedBox(height: AppSpace.md),
          ],
          _StreakBanner(firstWinEarnedToday: _gamification.firstWinEarnedToday),
          const SizedBox(height: AppSpace.md),
          _TodayPlan(subjects: _subjectProgress.subjects, onTap: _openRoute),
          const SizedBox(height: AppSpace.md),
          _SearchBar(onTap: () => context.push('/search')),
          const SizedBox(height: AppSpace.md),
          _HeroPanel(
            selectedClass: _selectedClass,
            examName: settings.examName,
            daysLeft: daysLeft,
            onClassTap: () => context.push('/elearning-class'),
            gamification: _gamification,
          ),
          const SizedBox(height: AppSpace.md),
          NexusSectionHeader(
            title: 'Continue learning',
            actionLabel: 'Class',
            onAction: () => context.push('/elearning-class'),
          ),
          _ContinueLearning(
            subjects: _subjectProgress.subjects,
            selectedClass: _selectedClass,
            onTap: _openRoute,
          ),
          NexusSectionHeader(
            title: 'Your subjects',
            actionLabel: 'All',
            onAction: () => context.push('/elearning-class'),
          ),
          _SubjectProgressSection(subjectProgress: _subjectProgress),
          const NexusSectionHeader(title: 'Quick actions'),
          _QuickActionsGrid(
            items: const [
              _HomeAction(
                'Book Scanner',
                'Scan a page, ask about it',
                Icons.document_scanner_outlined,
                '/scanner',
              ),
              _HomeAction(
                'Flashcards',
                'Active recall practice',
                Icons.style_outlined,
                '/flashcards',
              ),
              _HomeAction(
                'Multi-language tutor',
                'Ask in your own language',
                Icons.translate_outlined,
                '/multi-lang-tutor',
              ),
              _HomeAction(
                'Focus Timer',
                'Pomodoro focus',
                Icons.timer_outlined,
                '/focus',
              ),
            ],
            onTap: _openRoute,
          ),
          const NexusSectionHeader(title: 'More'),
          _MoreList(
            items: const [
              _HomeAction(
                'All features',
                'Curated tools, searchable',
                Icons.apps_outlined,
                '/features',
              ),
            ],
            onTap: _openRoute,
          ),
        ],
      ),
    );
  }
}

/// The daily flow: one revision task, one quiz, one doubt. This is the only
/// section that tells the student what to do *next* — everything else on the
/// home is reference material. Each row has a check that the student taps
/// when they finish it; the checks reset every day.
class _TodayPlan extends StatefulWidget {
  const _TodayPlan({required this.subjects, required this.onTap});

  final List<SubjectProgress> subjects;
  final ValueChanged<String> onTap;

  @override
  State<_TodayPlan> createState() => _TodayPlanState();
}

class _TodayPlanState extends State<_TodayPlan> {
  static const _planKeys = {
    'quiz': 'daily_plan_quiz',
    'revise': 'daily_plan_revise',
    'ask': 'daily_plan_ask',
  };
  final Set<String> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_todayKey:';
    final done = <String>{
      for (final key in _planKeys.keys)
        if (prefs.getBool('$prefix${_planKeys[key]}') == true) key,
    };
    if (!mounted) return;
    setState(
      () => _done
        ..clear()
        ..addAll(done),
    );
  }

  Future<void> _toggle(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storeKey = '$_todayKey:${_planKeys[key]}';
    final nowDone = !_done.contains(key);
    await prefs.setBool(storeKey, nowDone);
    if (!mounted) return;
    setState(() {
      if (nowDone) {
        _done.add(key);
      } else {
        _done.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subjects = widget.subjects;
    final started = subjects.where((s) => s.completedChapters > 0).toList();
    final weakest = started.isEmpty
        ? null
        : started.reduce((a, b) => a.progress <= b.progress ? a : b);
    final doneCount = _done.length;
    final allDone = doneCount == _planKeys.length;

    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_outlined, color: t.primary, size: 20),
              const SizedBox(width: AppSpace.xs),
              Text(
                "Today's plan",
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                allDone ? 'Done! 🎉' : '$doneCount/${_planKeys.length} done',
                style: context.text.bodySmall?.copyWith(
                  color: allDone ? t.statusPresent : t.inkFaint,
                  fontWeight: allDone ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
          if (doneCount > 0) ...[
            const SizedBox(height: AppSpace.xs),
            ClipRRect(
              borderRadius: AppRadius.brSm,
              child: LinearProgressIndicator(
                value: doneCount / _planKeys.length,
                backgroundColor: t.border,
                valueColor: AlwaysStoppedAnimation(
                  allDone ? t.statusPresent : t.primary,
                ),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xxs),
          _PlanRow(
            done: _done.contains('quiz'),
            icon: Icons.quiz_outlined,
            iconColor: t.primary,
            title: 'Daily Quiz',
            subtitle: '10 questions — earn XP',
            onTap: () => widget.onTap('/daily-quiz'),
            onCheck: () => _toggle('quiz'),
          ),
          _PlanRow(
            done: _done.contains('revise'),
            icon: Icons.auto_stories_outlined,
            iconColor: t.secondary,
            title: weakest == null
                ? 'Start: My syllabus'
                : 'Revise: ${weakest.name}',
            subtitle: weakest == null
                ? 'Begin your first chapter'
                : '${weakest.completedChapters}/${weakest.totalChapters} chapters done',
            onTap: () => widget.onTap(
              weakest == null ? '/elearning-class' : '/smart-revision',
            ),
            onCheck: () => _toggle('revise'),
          ),
          _PlanRow(
            done: _done.contains('ask'),
            icon: Icons.smart_toy_outlined,
            iconColor: t.statusLate,
            title: 'Ask Nexus',
            subtitle: 'Stuck? Ask in your own words',
            onTap: () => widget.onTap('/tutor'),
            onCheck: () => _toggle('ask'),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.done,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onCheck,
  });

  final bool done;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpace.minTapTarget),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onCheck,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done
                      ? t.statusPresent
                      : iconColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  done ? Icons.check : icon,
                  color: done ? t.surface : iconColor,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.typeExtras.bodyStrong.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? t.inkFaint : null,
                    ),
                  ),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// The "continue learning" pair. The primary card is data-driven: it resumes
/// the most recently studied subject when there is one, so the home reflects
/// the student's actual activity instead of a static menu.
class _ContinueLearning extends StatelessWidget {
  const _ContinueLearning({
    required this.subjects,
    required this.selectedClass,
    required this.onTap,
  });

  final List<SubjectProgress> subjects;
  final String? selectedClass;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final resumed = subjects.where((s) => s.lastStudied != null).toList()
      ..sort((a, b) => b.lastStudied!.compareTo(a.lastStudied!));
    final last = resumed.isEmpty ? null : resumed.first;

    return Row(
      children: [
        Expanded(
          child: _PrimaryActionCard(
            icon: Icons.auto_stories_outlined,
            title: last == null ? 'My syllabus' : 'Resume ${last.name}',
            subtitle: last == null
                ? selectedClass ?? 'Choose class'
                : '${last.completedChapters}/${last.totalChapters} chapters done',
            onTap: () =>
                onTap(last == null ? '/elearning-class' : '/elearning-class'),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _PrimaryActionCard(
            icon: Icons.flag_outlined,
            title: 'NCERT solutions',
            subtitle: 'Board-aligned answers',
            onTap: () => onTap('/ncert-solutions'),
          ),
        ),
      ],
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return NexusBanner(
      message:
          "You're browsing as a guest. Study tools work — sign in to save progress, streaks and quizzes.",
      kind: NexusBannerKind.info,
      actionLabel: 'Sign in',
      onAction: onSignIn,
    );
  }
}

/// Behavioral nudge: warns when the shield consumed a missed day, celebrates
/// the first-win XP bonus, or invites the student to their first win.
class _StreakBanner extends StatefulWidget {
  const _StreakBanner({required this.firstWinEarnedToday});

  final bool firstWinEarnedToday;

  @override
  State<_StreakBanner> createState() => _StreakBannerState();
}

class _StreakBannerState extends State<_StreakBanner> {
  bool? _quizDone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final quizDone =
        prefs.getBool('$todayKey:${_TodayPlanState._planKeys['quiz']}') == true;
    if (!mounted) return;
    setState(() => _quizDone = quizDone);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final streak = settings.streak;
    final quizDone = _quizDone ?? false;

    if (streak > 0 && settings.streakSaverUsed) {
      // A day was skipped but the shield kept the streak — the next missed
      // day will break it, so the warning is urgent.
      return NexusBanner(
        message:
            'Your streak shield saved your $streak-day streak once. Study today or it resets.',
        kind: NexusBannerKind.warning,
        actionLabel: 'Study now',
        onAction: () => context.push('/focus'),
      );
    }

    if (widget.firstWinEarnedToday) {
      return NexusBanner(
        message:
            'First win of the day! You earned a +${GamificationService.firstWinBonusXp} XP bonus.',
        kind: NexusBannerKind.info,
        actionLabel: 'View progress',
        onAction: () => context.push('/profile'),
      );
    }

    if (streak <= 1 && !quizDone) {
      // A fresh or reset streak with nothing earned today: the activation
      // nudge. After load() the streak is always >= 1, so this targets
      // newcomers and students whose streak just broke.
      return NexusBanner(
        message: 'Earn your first win — complete today\'s Daily Quiz.',
        kind: NexusBannerKind.info,
        actionLabel: 'Start quiz',
        onAction: () => context.push('/daily-quiz'),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: t.inkFaint, size: 20),
          const SizedBox(width: AppSpace.sm),
          Text(
            'Search topics, quizzes, doubts',
            style: context.text.bodyMedium?.copyWith(color: t.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brPill,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: t.primaryTint,
          borderRadius: AppRadius.brPill,
          border: Border.all(color: t.primaryTintBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: t.primary, size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(color: t.primary),
            ),
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
    final t = context.tokens;
    return NexusCard(
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
                      selectedClass == null
                          ? 'Ready to study?'
                          : 'Ready, $selectedClass learner?',
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'Your study dashboard',
                      style: context.text.headlineMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: AppSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  'Lv.${gamification.level}',
                  style: context.text.labelMedium?.copyWith(color: t.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: AppRadius.brMd,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level ${gamification.level} — ${gamification.levelTitle}',
                      style: context.typeExtras.bodyStrong,
                    ),
                    Text(
                      '${gamification.xpProgress}/${gamification.xpForNextLevel} XP',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                ClipRRect(
                  borderRadius: AppRadius.brSm,
                  child: LinearProgressIndicator(
                    value: gamification.levelProgress,
                    backgroundColor: t.border,
                    valueColor: AlwaysStoppedAnimation(t.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: _SmallStatus(
                  icon: Icons.school_outlined,
                  title: selectedClass ?? 'No class selected',
                  subtitle: selectedClass == null
                      ? 'Tap to set'
                      : 'Syllabus active',
                  onTap: onClassTap,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: _SmallStatus(
                  icon: Icons.event_available_outlined,
                  title: daysLeft == null
                      ? 'Exam target'
                      : '$daysLeft days left',
                  subtitle: daysLeft == null ? 'Set in Profile' : examName,
                ),
              ),
            ],
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
    final t = context.tokens;
    final subjects = subjectProgress.subjects.take(4).toList();
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final s = subjects[index];
          final color = s.progress >= 0.7
              ? t.statusPresent
              : s.progress >= 0.4
              ? t.statusLate
              : t.inkMuted;
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: AppSpace.sm),
            child: NexusCard(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(s.icon, style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      Text(
                        '${(s.progress * 100).round()}%',
                        style: context.text.labelMedium?.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    s.name,
                    style: context.typeExtras.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s.completedChapters}/${s.totalChapters} chapters',
                          style: context.text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (s.progress >= 0.85 && s.progress < 1)
                        Text(
                          'Almost there',
                          style: context.text.labelSmall?.copyWith(
                            color: t.statusPresent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: AppRadius.brSm,
                    child: LinearProgressIndicator(
                      value: s.progress,
                      backgroundColor: t.border,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
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
    return _ActionGrid(items: items, onTap: onTap);
  }
}

class _SmallStatus extends StatelessWidget {
  const _SmallStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpace.minTapTarget),
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          children: [
            Icon(icon, color: t.primary, size: 20),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typeExtras.bodyStrong,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
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
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, color: t.primary, size: 20),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: t.inkFaint),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: AppSpace.xxs),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall,
          ),
        ],
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
    final t = context.tokens;
    // P1-01: GridView(shrinkWrap:true, NeverScrollable) inside ListView — OK for
    // 4-item Quick Actions (no virtualization needed, avoids sliver complexity).
    // For 1M-scale or growing lists, migrate to PaginatedListView or CustomScrollView + SliverGrid
    // to enable true list virtualization and avoid laying out all children at once.
    // TODO: replace ListView+GridView(shrinkWrap) with PaginatedListView or CustomScrollView(
    //   slivers: [SliverGrid(...), ...]) when Quick Actions becomes dynamic/paginated.
    // intentionally not virtualized - 4 items
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.xs,
        mainAxisSpacing: AppSpace.xs,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return NexusCard(
          onTap: () => onTap(item.route),
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            children: [
              Icon(item.icon, color: t.primary, size: 22),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typeExtras.bodyStrong,
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
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
    final t = context.tokens;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: NexusCard(
              onTap: () => onTap(item.route),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.xs,
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: t.primary),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: context.typeExtras.bodyStrong),
                        Text(item.subtitle, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: t.inkFaint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeAction {
  const _HomeAction(this.title, this.subtitle, this.icon, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
