import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The curated catalogue of the features that actually ship value, with
/// search. Roughly seventy screens were built earlier; most of them were
/// variants of the same "prompt -> AI markdown" pattern with no backend
/// behind them. This screen only lists the features a student or parent
/// can genuinely use today: board-aligned learning, doubt solving,
/// exam practice, revision and progress.
///
/// Role-aware: teacher/parent surfaces only show for those roles (their
/// routes are router-blocked for everyone else anyway). Every feature is
/// checkable in place — tap the checkbox to mark it tried, no deep dive
/// needed.
class FeatureGalleryScreen extends StatefulWidget {
  const FeatureGalleryScreen({super.key});

  @override
  State<FeatureGalleryScreen> createState() => _FeatureGalleryScreenState();
}

class _FeatureGalleryScreenState extends State<FeatureGalleryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _tried = {};

  @override
  void initState() {
    super.initState();
    _loadTried();
  }

  Future<void> _loadTried() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_triedPrefix));
    setState(() {
      _tried
        ..clear()
        ..addAll(keys.map((k) => k.substring(_triedPrefix.length)));
    });
  }

  Future<void> _toggleTried(String route) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!_tried.remove(route)) _tried.add(route);
    });
    if (_tried.contains(route)) {
      await prefs.setBool('$_triedPrefix$route', true);
    } else {
      await prefs.remove('$_triedPrefix$route');
    }
  }

  static const _triedPrefix = 'gallery_tried_';

  /// Every user-facing destination, grouped the way a student would look for
  /// it rather than the way the code is organised. `roles` restricts a
  /// feature to teacher/parent surfaces; null means every role.
  static const List<_FeatureGroup> _groups = [
    _FeatureGroup('Learn', [
      _Feature(Icons.school_outlined, 'Class curriculum', 'Class, subject and topic learning paths.', '/elearning-class'),
      _Feature(Icons.smart_display_outlined, 'Learning shorts', 'Topic-wise micro lessons.', '/feed'),
      _Feature(Icons.flag_outlined, 'NCERT solutions', 'Solved answers, all classes.', '/ncert-solutions'),
      _Feature(Icons.play_circle_outline, 'YouTube summary', 'Summarise any lecture video.', '/youtube-summary'),
    ]),
    _FeatureGroup('Ask and solve', [
      _Feature(Icons.smart_toy_outlined, 'AI tutor', 'Guided doubts and explanations.', '/tutor'),
      _Feature(Icons.document_scanner_outlined, 'Book scanner', 'Scan a page and ask about it.', '/scanner'),
      _Feature(Icons.translate_outlined, 'Multi-language tutor', 'Ask in your own language.', '/multi-lang-tutor'),
      _Feature(Icons.calculate_outlined, 'Math word solver', 'Word problems, worked out.', '/math-word-solver'),
    ]),
    _FeatureGroup('Practise and test', [
      _Feature(Icons.quiz_outlined, 'Daily quiz', 'Short daily practice with XP.', '/daily-quiz'),
      _Feature(Icons.auto_awesome_outlined, 'Quiz generator', 'An AI-made quiz on any topic.', '/quiz-generator'),
      _Feature(Icons.assignment_outlined, 'Mock test', 'Timed, exam-style papers.', '/mock-test'),
      _Feature(Icons.emoji_events_outlined, 'JEE / NEET trainer', 'Entrance-exam drilling.', '/jee-neet-trainer'),
    ]),
    _FeatureGroup('Revise and remember', [
      _Feature(Icons.style_outlined, 'Flashcards', 'Active-recall decks.', '/flashcards'),
      _Feature(Icons.replay_outlined, 'Smart revision', 'Revise what you are weakest on.', '/smart-revision'),
      _Feature(Icons.schedule_outlined, 'Spaced repetition', 'Review at the right moment.', '/spaced-repetition'),
    ]),
    _FeatureGroup('Write and check', [
      _Feature(Icons.note_alt_outlined, 'Smart notes', 'Generate, keep, share and revise notes.', '/notes'),
    ]),
    _FeatureGroup('Plan and focus', [
      _Feature(Icons.event_available_outlined, 'AI study planner', 'Build a realistic timetable.', '/ai-study-planner'),
      _Feature(Icons.timer_outlined, 'Focus timer', 'Pomodoro study sessions.', '/focus'),
    ]),
    _FeatureGroup('Track progress', [
      _Feature(Icons.leaderboard_outlined, 'Leaderboard', 'Top scorers by XP.', '/leaderboard'),
    ]),
    _FeatureGroup('Classroom', [
      _Feature(Icons.meeting_room_outlined, 'My classroom', 'Attendance, tasks, syllabus notes and notifications.', '/classroom'),
      _Feature(Icons.menu_book_outlined, 'Post syllabus', 'AI converts your syllabus into study notes.', '/classroom', roles: ['teacher']),
      _Feature(Icons.how_to_reg_outlined, 'Mark attendance', 'Mark yourself present in class.', '/mark-attendance', roles: ['student', 'teacher']),
      _Feature(Icons.wifi_tethering_outlined, 'Offline exams', 'Host or join exams over hotspot or Bluetooth — no internet needed.', '/offline-exam', roles: ['student', 'teacher']),
    ]),
    _FeatureGroup('For teachers and parents', [
      _Feature(Icons.co_present_outlined, 'Teacher dashboard', 'Publish notes to your classes.', '/teacher-dashboard', roles: ['teacher']),
      _Feature(Icons.fact_check_outlined, 'Take attendance', 'Sessions, codes and rosters.', '/attendance', roles: ['teacher']),
      _Feature(Icons.family_restroom_outlined, 'Parent dashboard', "Follow your child's progress.", '/parent-dashboard', roles: ['parent']),
    ]),
    _FeatureGroup('Account', [
      _Feature(Icons.person_outline, 'Profile', 'Your class, streak and stats.', '/profile'),
      _Feature(Icons.tune_outlined, 'Settings', 'Appearance, privacy and study prefs.', '/settings'),
      _Feature(Icons.bolt_outlined, 'AI usage', 'Tokens used and remaining.', '/ai-usage'),
    ]),
  ];

  String get _currentRole => SecureApiService().role ?? 'student';

  List<_FeatureGroup> get _visibleGroups {
    final role = _currentRole;
    final query = _query.trim().toLowerCase();
    final groups = <_FeatureGroup>[];
    for (final group in _groups) {
      final cards = group.features
          .where((f) => (f.roles == null || f.roles!.contains(role)))
          .where(
            (f) =>
                query.isEmpty ||
                f.title.toLowerCase().contains(query) ||
                f.subtitle.toLowerCase().contains(query),
          )
          .toList();
      if (cards.isNotEmpty) groups.add(_FeatureGroup(group.title, cards));
    }
    return groups;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups;
    final total = _groups.fold<int>(
      0,
      (sum, g) =>
          sum +
          g.features.where((f) => f.roles == null || f.roles!.contains(_currentRole)).length,
    );

    return NexusScreen(
      title: 'All features',
      body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.lg,
                AppSpace.sm,
              ),
              child: NexusTextField(
                controller: _searchController,
                hint: 'Search $total features',
                icon: Icons.search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: NexusStateView.empty(
                          title: 'Nothing matches "${_query.trim()}"',
                          description: 'Try a different word.',
                          icon: Icons.search_off_outlined,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        0,
                        AppSpace.lg,
                        AppSpace.xxl,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpace.lg,
                                bottom: AppSpace.sm,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      group.title,
                                      style: context.text.headlineSmall,
                                    ),
                                  ),
                                  Text(
                                    '${group.features.where((f) => _tried.contains(f.route)).length}/${group.features.length}',
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.tokens.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final feature in group.features)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.xs,
                                ),
                                child: _FeatureTile(
                                  feature: feature,
                                  tried: _tried.contains(feature.route),
                                  onToggleTried: () =>
                                      _toggleTried(feature.route),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.feature,
    required this.tried,
    required this.onToggleTried,
  });

  final _Feature feature;
  final bool tried;
  final VoidCallback onToggleTried;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusCard(
      onTap: () => context.push(feature.route),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: tried
                  ? t.statusPresent.withValues(alpha: 0.15)
                  : t.primaryTint,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              tried ? Icons.check : feature.icon,
              color: tried ? t.statusPresent : t.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: context.typeExtras.bodyStrong.copyWith(
                    decoration: tried ? TextDecoration.lineThrough : null,
                    color: tried ? t.inkMuted : t.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  feature.subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: tried ? t.inkFaint : null,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: tried,
            activeColor: t.statusPresent,
            onChanged: (_) => onToggleTried(),
          ),
        ],
      ),
    );
  }
}

class _FeatureGroup {
  const _FeatureGroup(this.title, this.features);

  final String title;
  final List<_Feature> features;
}

class _Feature {
  const _Feature(this.icon, this.title, this.subtitle, this.route, {this.roles});

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  /// Roles allowed to see this feature; null means everyone.
  final List<String>? roles;
}
