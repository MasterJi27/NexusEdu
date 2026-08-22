import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/org_brand_mark.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/utils/tap_debounce.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_stat_tile.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

// TODO(P1): verified 2026-08-21 — all 4 bottom sheets (_DigestSheet, _ActivitySheet, _NotesSheet, _HistorySheet) use ClampingScrollPhysics via ListView.builder(physics: const ClampingScrollPhysics()) — already fixed.

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

  /// Best-effort extras, fetched in parallel after the roster: which child is
  /// in a live class right now, the AI weekly summary, and per-child activity.
  /// Each is optional — the dashboard renders whatever arrived.
  Map<String, dynamic>? _liveByChild;
  Map<String, dynamic>? _aiDigest;
  Map<String, List<dynamic>> _activityByChild = {};
  Map<String, dynamic>? _ranksByChild;
  Map<String, dynamic>? _historyByChild;
  bool _extrasLoading = true;

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
    unawaited(_loadExtras());
  }

  /// Live status, AI digest, activity, XP ranks and live-class history load
  /// without blocking the roster; each failing quietly on its own (network
  /// hiccup, AI down, empty data).
  Future<void> _loadExtras() async {
    setState(() => _extrasLoading = true);
    Map<String, dynamic>? live;
    Map<String, dynamic>? digest;
    Map<String, dynamic>? activity;
    Map<String, dynamic>? ranks;
    Map<String, dynamic>? history;
    try {
      live = await SecureApiService().getParentLiveStatus();
    } catch (e) {
      debugPrint('Parent live status failed: $e');
    }
    try {
      digest = await SecureApiService().getParentAiDigest();
    } catch (e) {
      debugPrint('Parent AI digest failed: $e');
    }
    try {
      activity = await SecureApiService().getParentActivity();
    } catch (e) {
      debugPrint('Parent activity failed: $e');
    }
    try {
      ranks = await SecureApiService().getParentRanks();
    } catch (e) {
      debugPrint('Parent ranks failed: $e');
    }
    try {
      history = await SecureApiService().getParentLiveHistory();
    } catch (e) {
      debugPrint('Parent live history failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _liveByChild = live == null
          ? null
          : {
              for (final child in (live['children'] as List? ?? const []))
                ((child as Map)['studentId'] as String? ?? ''): child,
            };
      _aiDigest = digest;
      _activityByChild = {
        for (final child in (activity?['children'] as List? ?? const []))
          ((child as Map)['studentId'] as String? ?? ''):
              child['items'] as List? ?? const [],
      };
      _ranksByChild = ranks == null
          ? null
          : {
              for (final child in (ranks['children'] as List? ?? const []))
                ((child as Map)['studentId'] as String? ?? ''): child,
            };
      _historyByChild = history == null
          ? null
          : {
              for (final child in (history['children'] as List? ?? const []))
                ((child as Map)['studentId'] as String? ?? ''): child,
            };
      _extrasLoading = false;
    });
  }

  Future<void> _switchToParentMode() async {
    setState(() => _switching = true);
    final result = await SecureApiService().updateProfile(role: 'parent');
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      setState(() => _switching = false);
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
              if (showMapErrorIfAny(dialogContext, result)) {
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
        showSuccessSnackBar(context, "Request sent — you'll see their progress once they approve it.");
      }
    }
  }

  Future<void> _unlinkChild(String studentId) async {
    final result = await SecureApiService().unlinkChild(studentId);
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      return;
    }
    _load();
  }

  /// Exit to the login screen so the parent can sign in to another account.
  /// Same confirm-first pattern as the profile screen's logout button.
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.tokens.surface,
        title: Text('Exit', style: ctx.text.titleLarge),
        content: Text(
          'Log out to switch to another account?',
          style: ctx.text.bodyMedium?.copyWith(color: ctx.tokens.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: ctx.tokens.statusAbsent,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthState.instance.logout();
      if (mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Parent Dashboard',
      actions: SecureApiService().isLoggedIn
          ? [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout / switch account',
                onPressed: _confirmLogout,
              ),
            ]
          : null,
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
          onPressed: () {
            if (TapDebounce.ready()) context.go('/login');
          },
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

    final liveNow = _liveByChild == null
        ? const <Map<String, dynamic>>[]
        : _liveByChild!.values
              .map((c) => Map<String, dynamic>.from(c as Map))
              .where((c) => c['live'] != null)
              .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadExtras();
      },
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
          if (liveNow.isNotEmpty) _buildLiveBanner(liveNow),
          if (_extrasLoading)
            const Padding(
              padding: EdgeInsets.only(top: AppSpace.sm),
              child: NexusStateView.loading(rows: 2),
            )
          else if (_aiDigest != null &&
              (_aiDigest!['children'] as List? ?? const []).isNotEmpty)
            _buildAiDigestCard(),
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

  Widget _buildLiveBanner(List<Map<String, dynamic>> liveNow) {
    final t = context.tokens;
    final names = liveNow.map((c) => c['name'].toString()).join(', ');
    final first = Map<String, dynamic>.from(liveNow.first['live'] as Map);
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      background: t.statusAbsent.withValues(alpha: 0.08),
      borderColor: t.statusAbsent.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: t.statusAbsent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: t.statusAbsent.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              liveNow.length == 1
                  ? '$names is in class right now — ${first['title']}'
                  : '$names are in class right now',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// AI-written weekly summary per child ("what happened this week" in plain
  /// language), with honest per-child attendance counts as fallback when the
  /// AI call fails or returns nothing.
  Widget _buildAiDigestCard() {
    final t = context.tokens;
    final insight = _aiDigest!['aiInsight'] as String?;
    final children = (_aiDigest!['children'] as List)
        .cast<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    final summaryLines = insight != null && insight.trim().isNotEmpty
        ? <String>[insight]
        : children.map((c) {
            final att = Map<String, dynamic>.from(
              c['attendance'] as Map? ?? const {},
            );
            final total = att['total'] as int? ?? 0;
            final present = att['present'] as int? ?? 0;
            final missed = (c['missedSubjects'] as List? ?? const [])
                .cast<String>();
            final core = total == 0
                ? '${c['name']}: no sessions recorded this week'
                : '${c['name']}: $present of $total sessions attended';
            return missed.isEmpty
                ? core
                : '$core · missed ${missed.join(', ')}';
          }).toList();
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.md),
      background: t.secondaryTint,
      borderColor: t.secondary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: t.secondary, size: 18),
              const SizedBox(width: AppSpace.xs),
              Text('This week at a glance', style: context.text.titleSmall),
            ],
          ),
          Builder(
            builder: (context) {
              final orgName = SecureApiService().organizationName?.trim();
              final hasOrg = orgName != null && orgName.isNotEmpty;
              if (!hasOrg) return const SizedBox.shrink();
              final logo = SecureApiService().orgLogoUrl;
              final hasLogo = logo != null && logo.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: hasLogo
                    ? OrgBrandMark(
                        name: orgName,
                        logoUrl: logo,
                        fallbackTitle: orgName,
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: t.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              orgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpace.xs),
          for (final line in summaryLines)
            Text(
              line,
              style: context.text.bodyMedium?.copyWith(
                color: t.ink,
                height: 1.4,
              ),
            ),
          if (insight != null && insight.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              'Written by AI from attendance records.',
              style: context.text.labelSmall?.copyWith(color: t.inkMuted),
            ),
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
    final live = _liveByChild?[child['id']]?['live'] as Map?;
    final rank = _ranksByChild?[child['id']]?['rank'] as int?;
    final totalStudents =
        _ranksByChild?[child['id']]?['totalStudents'] as int? ?? 0;

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
                backgroundColor: t.surfaceAlt,
                backgroundImage: (child['photoUrl'] is String &&
                        (child['photoUrl'] as String).isNotEmpty)
                    ? CachedNetworkImageProvider(
                        child['photoUrl'] as String,
                        maxWidth: 64,
                        maxHeight: 64,
                      )
                    : null,
                onBackgroundImageError: (child['photoUrl'] is String &&
                        (child['photoUrl'] as String).isNotEmpty)
                    ? (_, _) {}
                    : null,
                child: (child['photoUrl'] == null ||
                        (child['photoUrl'] is String &&
                            (child['photoUrl'] as String).isEmpty))
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
          // Organization context: show school/org branding when child data
          // carries it, otherwise fall back to the signed-in parent's org
          // (SecureApiService cross-user propagation). Null-safe with fallback.
          Builder(
            builder: (context) {
              final childOrgRaw =
                  (child['organizationName'] as String?) ??
                  (child['orgName'] as String?) ??
                  (child['schoolName'] as String?);
              final childOrg = childOrgRaw?.trim();
              final childLogo =
                  (child['orgLogoUrl'] as String?) ??
                  (child['organizationLogoUrl'] as String?);
              final fallbackOrg = SecureApiService().organizationName?.trim();
              final hasChildOrg = childOrg != null && childOrg.isNotEmpty;
              final hasFallback = fallbackOrg != null && fallbackOrg.isNotEmpty;
              final displayOrg = hasChildOrg
                  ? childOrg
                  : (hasFallback ? fallbackOrg : null);
              final rawLogo = childLogo?.trim().isNotEmpty == true
                  ? childLogo!.trim()
                  : SecureApiService().orgLogoUrl;
              final hasLogo = rawLogo != null && rawLogo.trim().isNotEmpty;
              final hasOrg = displayOrg != null && displayOrg.isNotEmpty;
              if (!hasOrg) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: hasLogo
                    ? OrgBrandMark(
                        name: displayOrg,
                        logoUrl: rawLogo,
                        fallbackTitle: displayOrg,
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: t.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'School: $displayOrg',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpace.md),
          if (live != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                children: [
                  Icon(Icons.circle, color: t.statusAbsent, size: 10),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    'LIVE now — ${live['title'] ?? 'class in progress'} '
                    '(${live['sectionLabel'] ?? ''})',
                    style: context.text.labelMedium?.copyWith(
                      color: t.statusAbsent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
              if (rank != null) ...[
                Expanded(
                  child: _buildStat(
                    Icons.emoji_events_outlined,
                    '#$rank of $totalStudents',
                    t.statusPresent,
                  ),
                ),
              ],
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
          if (child['demo'] != true) ...[
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openActivitySheet(
                  child['id'] as String,
                  child['name'] as String? ?? '',
                ),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Recent activity'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openNotesSheet(
                  child['id'] as String,
                  child['name'] as String? ?? '',
                  child['gradeLevel'] as String? ?? '',
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Teacher notes'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openHistorySheet(
                  child['id'] as String,
                  child['name'] as String? ?? '',
                ),
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('Classes this week'),
              ),
            ),
          ],
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
        final eligible = summary['eligible'] as bool?;
        final color = eligible == false ? t.statusAbsent : t.statusPresent;
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

  /// Last 7 days of the child's in-app activity (quizzes, shorts, notes) —
  /// already fetched with the dashboard, so the sheet is instant.
  void _openActivitySheet(String studentId, String childName) {
    final items = _activityByChild[studentId] ?? const <dynamic>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _ActivitySheet(childName: childName, items: items),
    );
  }

  /// Published teacher notes for the child's grade. Fetched on demand (one
  /// grade can serve several children) and shown in a sheet; the sheet
  /// refetches on pull so edits by the teacher show up.
  void _openNotesSheet(String studentId, String childName, String gradeLevel) {
    if (gradeLevel.isEmpty) {
      showErrorSnackBar(context, '$childName has no grade level on file.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _NotesSheet(
        studentId: studentId,
        childName: childName,
        gradeLevel: gradeLevel,
      ),
    );
  }

  /// Live classes that already ran this week in the child's sections —
  /// already fetched with the dashboard, so the sheet is instant.
  void _openHistorySheet(String studentId, String childName) {
    final items = _historyByChild?[studentId]?['items'] ?? const <dynamic>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _HistorySheet(childName: childName, items: items),
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
          Builder(
            builder: (context) {
              final orgFromChild =
                  (_child?['organizationName'] as String?)?.trim() ??
                  (_child?['orgName'] as String?)?.trim();
              final fallback = SecureApiService().organizationName?.trim();
              final displayOrg =
                  (orgFromChild != null && orgFromChild.isNotEmpty)
                  ? orgFromChild
                  : fallback;
              final hasOrg = displayOrg != null && displayOrg.isNotEmpty;
              if (!hasOrg) return const SizedBox.shrink();
              final rawLogo =
                  (_child?['orgLogoUrl'] as String?)?.trim().isNotEmpty == true
                  ? (_child!['orgLogoUrl'] as String).trim()
                  : SecureApiService().orgLogoUrl;
              final hasLogo = rawLogo != null && rawLogo.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: hasLogo
                    ? OrgBrandMark(
                        name: displayOrg,
                        logoUrl: rawLogo,
                        fallbackTitle: displayOrg,
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: context.tokens.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'School: $displayOrg',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: context.tokens.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
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
                  // 1M fix: shrinkWrap kept for bottom-sheet sizing (inside Flexible/ConstrainedBox);
                  // ClampingScrollPhysics avoids nested bounce and keeps scroll virtualization correct.
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
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

/// A child's last-7-days in-app activity: what they did in NexusEdu, not
/// their private content. Items are the app's own activity log (quiz done,
/// short watched, note saved).
class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({required this.childName, required this.items});

  final String childName;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$childName — recent activity', style: context.text.titleMedium),
          Builder(
            builder: (context) {
              final orgName = SecureApiService().organizationName?.trim();
              final hasOrg = orgName != null && orgName.isNotEmpty;
              if (!hasOrg) return const SizedBox.shrink();
              final logo = SecureApiService().orgLogoUrl;
              final hasLogo = logo != null && logo.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: hasLogo
                    ? OrgBrandMark(
                        name: orgName,
                        logoUrl: logo,
                        fallbackTitle: orgName,
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: t.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'School: $orgName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpace.sm),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Text(
                'No activity in the last 7 days yet. It fills in as your child '
                'completes quizzes, watches shorts and saves notes.',
                style: context.text.bodySmall?.copyWith(color: t.inkMuted),
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                // 1M fix: shrinkWrap kept for sheet sizing (inside Flexible/ConstrainedBox);
                // ClampingScrollPhysics avoids nested scroll bounce.
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = Map<String, dynamic>.from(items[i] as Map);
                    return _buildItemRow(ctx, t, item);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext ctx,
    AppTokens t,
    Map<String, dynamic> item,
  ) {
    final action = (item['action'] as String? ?? '').toUpperCase();
    final (IconData icon, String label) = switch (action) {
      'QUIZ_COMPLETED' => (Icons.quiz_outlined, 'Completed a quiz'),
      'SHORT_COMPLETED' => (
        Icons.play_circle_outline,
        'Watched a learning short',
      ),
      'NOTE_SAVED' => (Icons.note_outlined, 'Saved a note'),
      _ => (Icons.bolt, action.replaceAll('_', ' ').toLowerCase()),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        children: [
          Icon(icon, color: t.primary, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(label, style: ctx.text.bodyMedium)),
          Text(
            _relativeTime(item['timestamp']),
            style: ctx.text.labelSmall?.copyWith(color: t.inkMuted),
          ),
        ],
      ),
    );
  }

  String _relativeTime(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Published teacher notes for the child's grade. Fetched on demand from
/// the existing teacher-notes endpoint (parent sees the same published
/// notes as students); pull-to-refresh picks up new notes by the teacher.
class _NotesSheet extends StatefulWidget {
  const _NotesSheet({
    required this.studentId,
    required this.childName,
    required this.gradeLevel,
  });

  final String studentId;
  final String childName;
  final String gradeLevel;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  bool _isLoading = true;
  List<dynamic> _notes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<dynamic> notes = const [];
    try {
      notes = await SecureApiService().getTeacherNotes(
        gradeLevel: widget.gradeLevel,
      );
    } catch (e) {
      debugPrint('Parent teacher notes failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  void _openNote(Map<String, dynamic> note) {
    final teacher = (note['teacher'] as Map?)?['name'] as String? ?? 'Teacher';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(note['title'] as String? ?? ''),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${note['subject'] ?? ''} • $teacher',
                style: context.text.labelMedium?.copyWith(
                  color: context.tokens.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(note['content'] as String? ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.childName} — ${widget.gradeLevel} teacher notes',
            style: context.text.titleMedium,
          ),
          Builder(
            builder: (context) {
              final orgName = SecureApiService().organizationName?.trim();
              final hasOrg = orgName != null && orgName.isNotEmpty;
              if (!hasOrg) return const SizedBox.shrink();
              final logo = SecureApiService().orgLogoUrl;
              final hasLogo = logo != null && logo.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: hasLogo
                    ? OrgBrandMark(
                        name: orgName,
                        logoUrl: logo,
                        fallbackTitle: orgName,
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: t.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'School: $orgName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpace.sm),
          if (_isLoading)
            const NexusStateView.loading(rows: 3)
          else if (_notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Text(
                'No published notes for this grade yet.',
                style: context.text.bodySmall?.copyWith(color: t.inkMuted),
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: RefreshIndicator(
                  onRefresh: _load,
                  // 1M fix: shrinkWrap kept for sheet sizing; ClampingScrollPhysics avoids nested bounce
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _notes.length,
                    itemBuilder: (ctx, i) {
                      final note = Map<String, dynamic>.from(_notes[i] as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(
                          note['title'] as String? ?? '',
                          style: context.text.bodyMedium,
                        ),
                        subtitle: Text(
                          '${note['subject'] ?? ''}'
                          '${note['topic'] != null ? ' • ${note['topic']}' : ''}',
                          style: context.text.labelSmall?.copyWith(
                            color: t.inkMuted,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openNote(note),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Live classes that already ran this week in the child's sections — what
/// the class did, not a claim the child was present. Fetched with the
/// dashboard, so the sheet is instant.
class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.childName, required this.items});

  final String childName;
  final List<dynamic> items;

  String _formatSession(Map<String, dynamic> s) {
    final start = DateTime.tryParse(s['startedAt']?.toString() ?? '');
    final end = DateTime.tryParse(s['endedAt']?.toString() ?? '');
    if (start == null) return '';
    String day = '${start.day} ${_shortMonth(start.month)}';
    if (start.year != DateTime.now().year) day = '$day ${start.year}';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    String out = '$day, $time';
    if (end != null) {
      final mins = end.difference(start).inMinutes;
      if (mins > 0) out += ' · ${mins}m';
    }
    return out;
  }

  String _shortMonth(int m) {
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
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$childName — classes this week',
            style: context.text.titleMedium,
          ),
          Builder(
            builder: (context) {
              final orgName = SecureApiService().organizationName?.trim();
              final hasOrg = orgName != null && orgName.isNotEmpty;
              if (!hasOrg) return const SizedBox.shrink();
              final logo = SecureApiService().orgLogoUrl;
              final hasLogo = logo != null && logo.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.xs),
                child: hasLogo
                    ? OrgBrandMark(
                        name: orgName,
                        logoUrl: logo,
                        fallbackTitle: orgName,
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: t.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'School: $orgName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpace.sm),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Text(
                'No live classes recorded for this child this week.',
                style: context.text.bodySmall?.copyWith(color: t.inkMuted),
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                // 1M fix: shrinkWrap kept for sheet sizing; ClampingScrollPhysics avoids nested bounce
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final s = Map<String, dynamic>.from(items[i] as Map);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.school_outlined),
                      title: Text(
                        s['title'] as String? ?? 'Live class',
                        style: context.text.bodyMedium,
                      ),
                      subtitle: Text(
                        [
                          if (s['section'] is Map)
                            (s['section'] as Map)['label'] as String? ?? '',
                          _formatSession(s),
                        ].where((x) => x.isNotEmpty).join(' • '),
                        style: context.text.labelSmall?.copyWith(
                          color: t.inkMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
