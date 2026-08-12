import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_stat_tile.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _isLoading = true;
  bool _isParent = false;
  bool _switching = false;
  List<dynamic> _children = [];
  List<dynamic> _pendingLinks = [];

  /// Sample children shown to guests so a parent can see what the dashboard
  /// looks like before signing in. Every value is fictional and the UI marks
  /// it as demo — per PRODUCT.md, an on-screen number must trace to the user's
  /// own data or be labelled.
  static final List<Map<String, dynamic>> _demoChildren = [
    {
      'id': 'demo-aarav',
      'demo': true,
      'name': 'Aarav Sharma',
      'gradeLevel': 'Class 10',
      'schoolBoard': 'CBSE',
      'xp': 2450,
      'streak': 18,
      'strongSubjects': ['Mathematics', 'Science'],
      'weakSubjects': ['English'],
    },
    {
      'id': 'demo-diya',
      'demo': true,
      'name': 'Diya Sharma',
      'gradeLevel': 'Class 8',
      'schoolBoard': 'CBSE',
      'xp': 1290,
      'streak': 6,
      'strongSubjects': ['Hindi'],
      'weakSubjects': ['Science', 'Social Science'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = SecureApiService();
    if (!api.isLoggedIn) {
      setState(() {
        _isLoading = false;
        _isParent = false;
        _children = _demoChildren;
      });
      return;
    }
    if (api.role != 'parent') {
      setState(() {
        _isParent = false;
        _isLoading = false;
      });
      return;
    }
    final links = await api.getParentLinks();
    if (!mounted) return;
    setState(() {
      _isParent = true;
      _children = links
          .where((l) => (l as Map)['status'] == 'approved')
          .toList();
      _pendingLinks = links
          .where((l) => (l as Map)['status'] == 'pending')
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _switchToParentMode() async {
    setState(() => _switching = true);
    final result = await SecureApiService().updateProfile(role: 'parent');
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() => _switching = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['error'].toString())));
      return;
    }
    setState(() => _switching = false);
    _load();
  }

  Future<void> _openLinkChildDialog() async {
    final emailController = TextEditingController();
    final linked = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link your child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your child's NexusEdu account email. They'll need to "
              'approve the request before you can see their progress.',
            ),
            const SizedBox(height: AppSpace.sm),
            NexusTextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              label: "Child's email",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Send request',
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              final result = await SecureApiService().linkChild(email);
              if (!dialogContext.mounted) return;
              if (result['error'] != null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(result['error'].toString())),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
          ),
        ],
      ),
    );
    emailController.dispose();
    if (linked == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Request sent — you'll see their progress once they approve it.",
            ),
          ),
        );
      }
    }
  }

  Future<void> _unlinkChild(String studentId) async {
    final result = await SecureApiService().unlinkChild(studentId);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['error'].toString())));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Parent Dashboard',
      floatingActionButton: _isParent
          ? FloatingActionButton.extended(
              onPressed: _openLinkChildDialog,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Link child'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !SecureApiService().isLoggedIn
          ? _buildDemoExperience()
          : !_isParent
          ? _buildSwitchToParentPrompt()
          : _children.isEmpty && _pendingLinks.isEmpty
          ? _buildEmptyState()
          : _buildChildrenList(),
    );
  }

  /// Guest view: the same dashboard shell with sample children, every number
  /// clearly marked as demo, and one path into sign-in.
  Widget _buildDemoExperience() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
        100,
      ),
      children: [
        NexusBanner(
          message:
              "You're seeing a demo. Sign in and link your child's account to see their real progress here.",
          kind: NexusBannerKind.info,
          actionLabel: 'Sign in',
          onAction: () => context.go('/login'),
        ),
        const SizedBox(height: AppSpace.md),
        _buildParentOverview(totalXp: 3740, bestStreak: 18),
        const SizedBox(height: AppSpace.md),
        Text('Linked children', style: context.text.titleMedium),
        const SizedBox(height: AppSpace.sm),
        for (final raw in _children)
          _buildChildCard(Map<String, dynamic>.from(raw as Map)),
        const SizedBox(height: AppSpace.md),
        NexusButton(
          label: 'Sign in to track your child',
          icon: Icons.login,
          fullWidth: true,
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: AppSpace.xs),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Create a parent account'),
        ),
      ],
    );
  }

  Widget _buildPendingLinksCard() {
    final t = context.tokens;
    return NexusCard(
      background: t.secondaryTint,
      borderColor: t.secondary.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, color: t.secondary, size: 20),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  _pendingLinks.length == 1
                      ? 'Waiting for 1 request to be approved'
                      : 'Waiting for ${_pendingLinks.length} requests to be approved',
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          for (final raw in _pendingLinks)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                (raw as Map)['name']?.toString() ?? 'Pending student',
                style: context.text.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchToParentPrompt() {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, color: t.primary, size: 48),
            const SizedBox(height: AppSpace.md),
            Text(
              'Your account is registered as ${SecureApiService().role ?? 'student'}.',
              textAlign: TextAlign.center,
              style: context.text.titleSmall,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Switch to Parent mode to link your child\'s account and see their real progress.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: AppSpace.lg),
            NexusButton(
              label: 'Switch to Parent mode',
              icon: Icons.family_restroom,
              isLoading: _switching,
              onPressed: _switching ? null : _switchToParentMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_pendingLinks.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: _buildPendingLinksCard(),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: NexusStateView.empty(
          title: 'No children linked yet.',
          description:
              'Tap "Link child" and enter their account email to see their real progress here.',
          icon: Icons.person_search,
        ),
      ),
    );
  }

  Widget _buildChildrenList() {
    final totalXp = _children.fold<int>(
      0,
      (sum, child) =>
          sum + ((child as Map<String, dynamic>)['xp'] as int? ?? 0),
    );
    final bestStreak = _children.fold<int>(0, (max, child) {
      final streak = (child as Map<String, dynamic>)['streak'] as int? ?? 0;
      return streak > max ? streak : max;
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          100,
        ),
        children: [
          _buildParentOverview(totalXp: totalXp, bestStreak: bestStreak),
          const SizedBox(height: AppSpace.md),
          if (_pendingLinks.isNotEmpty) _buildPendingLinksCard(),
          if (_children.isNotEmpty) ...[
            Text('Linked children', style: context.text.titleMedium),
            const SizedBox(height: AppSpace.sm),
            for (int index = 0; index < _children.length; index++)
              _buildChildCard(_children[index] as Map<String, dynamic>),
          ],
        ],
      ),
    );
  }

  Widget _buildParentOverview({required int totalXp, required int bestStreak}) {
    final t = context.tokens;
    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Family learning overview', style: context.text.headlineSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Track ${_children.length} linked ${_children.length == 1 ? 'child' : 'children'} from one parent account.',
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: NexusStatTile(
                  icon: Icons.family_restroom,
                  iconColor: t.primary,
                  value: '${_children.length}',
                  label: 'Children',
                  bordered: false,
                  centered: true,
                ),
              ),
              Expanded(
                child: NexusStatTile(
                  icon: Icons.star,
                  iconColor: t.secondaryFill,
                  value: '$totalXp',
                  label: 'Total XP',
                  bordered: false,
                  centered: true,
                ),
              ),
              Expanded(
                child: NexusStatTile(
                  icon: Icons.local_fire_department,
                  iconColor: t.statusLate,
                  value: '$bestStreak',
                  label: 'Best streak',
                  bordered: false,
                  centered: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final t = context.tokens;
    final weak = (child['weakSubjects'] as List?)?.cast<String>() ?? const [];
    final strong =
        (child['strongSubjects'] as List?)?.cast<String>() ?? const [];
    final xp = child['xp'] as int? ?? 0;
    final streak = child['streak'] as int? ?? 0;

    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: child['photoUrl'] != null
                    ? NetworkImage(child['photoUrl'])
                    : null,
                child: child['photoUrl'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child['name'] as String? ?? '',
                      style: context.text.titleMedium,
                    ),
                    Text(
                      [
                        if (child['gradeLevel'] != null) child['gradeLevel'],
                        if (child['schoolBoard'] != null) child['schoolBoard'],
                      ].join(' • '),
                      style: context.text.bodySmall?.copyWith(
                        color: t.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'unlink', child: Text('Unlink')),
                ],
                onSelected: (v) {
                  if (v == 'unlink') _unlinkChild(child['id'] as String);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: _buildStat(Icons.star, '$xp XP', t.secondaryFill),
              ),
              Expanded(
                child: _buildStat(
                  Icons.local_fire_department,
                  '$streak day streak',
                  t.statusLate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (child['demo'] == true)
            Row(
              children: [
                Icon(Icons.visibility_outlined, color: t.inkMuted, size: 18),
                const SizedBox(width: AppSpace.xs),
                Text(
                  'Demo profile — sample data',
                  style: context.text.labelMedium?.copyWith(
                    color: t.inkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            _buildAttendanceRow(child['id'] as String),
          const SizedBox(height: AppSpace.xs),
          if (child['demo'] != true)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openDigest(
                  child['id'] as String,
                  child['name'] as String? ?? '',
                ),
                icon: const Icon(Icons.calendar_view_day_outlined, size: 18),
                label: const Text('7-day attendance digest'),
              ),
            ),
          if (strong.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('Strong subjects', style: context.text.labelMedium),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: strong
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      labelStyle: context.text.labelSmall?.copyWith(
                        color: t.statusPresent,
                      ),
                      backgroundColor: t.statusPresent.withValues(alpha: 0.12),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (weak.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text('Needs attention', style: context.text.labelMedium),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: weak
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      labelStyle: context.text.labelSmall?.copyWith(
                        color: t.statusAbsent,
                      ),
                      backgroundColor: t.statusAbsent.withValues(alpha: 0.12),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (weak.isEmpty && strong.isEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'No subject data yet — this fills in as your child completes lessons.',
              style: context.text.bodySmall?.copyWith(
                color: t.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Real attendance, fetched per child on demand rather than in the initial
  /// batch load — a parent with several children shouldn't wait on N extra
  /// round-trips just to see the roster.
  Widget _buildAttendanceRow(String studentId) {
    final t = context.tokens;
    return FutureBuilder<Map<String, dynamic>>(
      future: SecureApiService().getChildAttendanceHistory(studentId),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData || snapshot.data?['summary'] == null) {
          return Row(
            children: [
              Icon(Icons.fact_check_outlined, color: t.inkMuted, size: 18),
              const SizedBox(width: AppSpace.xs),
              Text(
                'Attendance —',
                style: context.text.labelMedium?.copyWith(color: t.inkMuted),
              ),
            ],
          );
        }
        final summary = Map<String, dynamic>.from(
          snapshot.data!['summary'] as Map,
        );
        final pct = summary['percentage'] as int?;
        final total = summary['total'] as int? ?? 0;
        if (pct == null || total == 0) {
          return Row(
            children: [
              Icon(Icons.fact_check_outlined, color: t.inkMuted, size: 18),
              const SizedBox(width: AppSpace.xs),
              Text(
                'No attendance recorded yet',
                style: context.text.labelMedium?.copyWith(color: t.inkMuted),
              ),
            ],
          );
        }
        final color = pct < 75 ? t.statusAbsent : t.statusPresent;
        return Row(
          children: [
            Icon(Icons.fact_check_outlined, color: color, size: 18),
            const SizedBox(width: AppSpace.xs),
            Text(
              '$pct% attendance',
              style: context.text.labelMedium?.copyWith(color: color),
            ),
            Text(' · last $total sessions', style: context.text.bodySmall),
          ],
        );
      },
    );
  }

  /// Per-day rollup of a child's attendance for the last week — the "what
  /// happened at school" answer. Loaded on demand, one round-trip, per child.
  Future<void> _openDigest(String studentId, String childName) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _DigestSheet(studentId: studentId, childName: childName),
    );
  }

  Widget _buildStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpace.xs),
        Text(label, style: context.text.labelMedium?.copyWith(color: color)),
      ],
    );
  }
}

class _DigestSheet extends StatefulWidget {
  const _DigestSheet({required this.studentId, required this.childName});

  final String studentId;
  final String childName;

  @override
  State<_DigestSheet> createState() => _DigestSheetState();
}

class _DigestSheetState extends State<_DigestSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _child;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final digest = await SecureApiService().getParentDigest(days: 7);
    if (!mounted) return;
    final children = (digest['children'] as List?) ?? const <dynamic>[];
    setState(() {
      _child = children
          .cast<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .where((c) => c['studentId'] == widget.studentId)
          .firstOrNull;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.lg,
        right: AppSpace.lg,
        top: AppSpace.lg,
        bottom: AppSpace.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.childName} — last 7 days',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppSpace.sm),
          if (_isLoading)
            const NexusStateView.loading(rows: 3)
          else if (_child == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Text(
                'No attendance sessions in the last 7 days.',
                style: context.text.bodySmall,
              ),
            )
          else ...[
            _buildDigestSummary(
              t,
              Map<String, dynamic>.from(_child!['summary'] as Map),
            ),
            const SizedBox(height: AppSpace.md),
            if ((_child!['days'] as List? ?? const []).isEmpty)
              Text(
                'No sessions recorded this week.',
                style: context.text.bodySmall,
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: (_child!['days'] as List).length,
                    itemBuilder: (ctx, i) => _buildDayRow(
                      t,
                      Map<String, dynamic>.from(
                        (_child!['days'] as List)[i] as Map,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDigestSummary(AppTokens t, Map<String, dynamic> summary) {
    final pct = summary['percentage'] as int?;
    final total = summary['total'] as int? ?? 0;
    final color = pct == null
        ? t.inkMuted
        : (pct < 75 ? t.statusAbsent : t.statusPresent);
    return NexusCard(
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      child: Row(
        children: [
          Text(
            pct != null ? '$pct%' : '—',
            style: context.typeExtras.figureLg.copyWith(color: color),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              '$total session${total == 1 ? '' : 's'} this week',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(AppTokens t, Map<String, dynamic> day) {
    final date = day['date'] as String? ?? '';
    final present = day['present'] as int? ?? 0;
    final late = day['late'] as int? ?? 0;
    final absent = day['absent'] as int? ?? 0;
    final leave = day['leave'] as int? ?? 0;
    final sessions = (day['sessions'] as List?) ?? const <dynamic>[];
    final missed = sessions
        .cast<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .where((s) => s['status'] != 'present')
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: NexusCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: context.typeExtras.bodyStrong,
                  ),
                ),
                Text(
                  '$present present · $late late · $absent absent · $leave leave',
                  style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
            if (missed.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              for (final m in missed)
                Text(
                  '${m['subject']} (${m['section']}): ${m['status']}',
                  style: context.text.bodySmall?.copyWith(
                    color: m['status'] == 'absent'
                        ? t.statusAbsent
                        : t.statusLate,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]}';
  }
}
