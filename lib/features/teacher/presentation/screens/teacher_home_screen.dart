import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/features/classroom/presentation/screens/live_class_screen.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_stat_tile.dart';
import 'package:nexus_edu/shared/widgets/org_brand_mark.dart';

/// Teacher landing: the day's teaching cockpit. Real numbers from
/// `GET /api/classroom/teacher/home`, live-now banner, quick actions and
/// recent sections/live classes — one screen, one round trip.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;
  bool _joiningLive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await SecureApiService().getTeacherHomeResult();
    if (!mounted) return;
    if (!handleResultError(context, result)) {
      setState(() {
        _loading = false;
        _error = (result as Failure).message;
      });
      return;
    }
    setState(() {
      _loading = false;
      _data = (result as Success<Map<String, dynamic>>).data;
    });
  }

  /// Reopens a live class the teacher already started (e.g. they left and
  /// re-entered the app): fresh join token, host connection.
  Future<void> _joinLiveNow() async {
    final live = _data?['liveNow'] as Map<String, dynamic>?;
    if (live == null || _joiningLive) return;
    final liveId = live['id']?.toString() ?? '';
    if (liveId.isEmpty) {
      if (mounted) showErrorSnackBar(context, 'Invalid live session');
      return;
    }
    setState(() => _joiningLive = true);
    try {
      final result = await SecureApiService().getLiveClassTokenResult(liveId);
      if (!mounted) return;
      if (!handleResultError(context, result)) {
        return;
      }
      final data = (result as Success<Map<String, dynamic>>).data;
      final userId = SecureApiService().userId;
      if (userId == null) return;
      final liveSessionId = data['liveSessionId']?.toString() ?? '';
      final appId = data['appId']?.toString() ?? '';
      final token = data['token']?.toString() ?? '';
      final channelName = data['channelName']?.toString() ?? '';
      if (liveSessionId.isEmpty ||
          appId.isEmpty ||
          token.isEmpty ||
          channelName.isEmpty) {
        if (mounted) showErrorSnackBar(context, 'Invalid live session data');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveClassScreen(
            liveSessionId: liveSessionId,
            appId: appId,
            token: token,
            channelName: channelName,
            userAccount: userId,
            isHost: true,
            recordingAllowed: data['recordingAllowed'] as bool? ?? false,
            title:
                data['title']?.toString() ??
                live['title']?.toString() ??
                'Live class',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _joiningLive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = SecureApiService();
    final payloadName = _data?['organizationName'] as String?;
    final payloadLogo = _data?['orgLogoUrl'] as String?;
    // Payload wins when present; SecureApiService cache is the fallback so the
    // app bar still brands correctly on a cached home load or after a profile
    // refresh that updated the org without re-fetching teacher/home.
    final orgName =
        (payloadName?.isNotEmpty == true ? payloadName : null) ??
        (api.organizationName?.isNotEmpty == true
            ? api.organizationName
            : null);
    final orgLogoUrl =
        (payloadLogo?.isNotEmpty == true ? payloadLogo : null) ??
        (api.orgLogoUrl?.isNotEmpty == true ? api.orgLogoUrl : null);
    return NexusScreen(
      title: 'Teacher home',
      titleWidget: OrgBrandMark(
        fallbackTitle: 'Teacher home',
        name: orgName,
        logoUrl: orgLogoUrl,
      ),
      actions: [
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.person_outline),
          onPressed: () => context.go('/profile'),
        ),
      ],
      onRefresh: _load,
      body: _loading
          ? const NexusStateView.loading(rows: 5)
          : _error != null
          ? NexusStateView.error(message: _error!, onRetry: _load)
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = context.tokens;
    final data = _data!;
    final liveNow = data['liveNow'] as Map<String, dynamic>?;
    final sections = (data['recentSections'] as List?) ?? const [];
    final recentLive = (data['recentLive'] as List?) ?? const [];
    final name = SecureApiService().userName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.xxl,
      ),
      children: [
        Text(
          'Namaste, $name 👋',
          style: context.text.headlineSmall?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpace.xxs),
        Text(
          'Here\'s your teaching day at a glance.',
          style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: NexusStatTile(
                icon: Icons.meeting_room_outlined,
                iconColor: t.primary,
                value: '${data['sectionCount'] ?? 0}',
                label: 'Sections',
                centered: true,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: NexusStatTile(
                icon: Icons.group_outlined,
                iconColor: t.secondary,
                value: '${data['studentCount'] ?? 0}',
                label: 'Students',
                centered: true,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: NexusStatTile(
                icon: Icons.note_alt_outlined,
                iconColor: t.statusPresent,
                value: '${data['noteCount'] ?? 0}',
                label: 'Notes',
                centered: true,
              ),
            ),
          ],
        ),
        if (liveNow != null) ...[
          const SizedBox(height: AppSpace.md),
          NexusBanner(
            message:
                'Live now: ${liveNow['title']} · ${liveNow['sectionLabel']}',
            actionLabel: _joiningLive ? 'Joining…' : 'Open',
            onAction: _joiningLive ? null : _joinLiveNow,
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        NexusSectionHeader(title: 'Quick actions', spaceAbove: 0),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpace.sm,
          crossAxisSpacing: AppSpace.sm,
          // Fixed tile height, not aspect-ratio: aspect-ratio tiles shrink
          // with the screen width and the icon+label content overflows the
          // bottom (12 px on narrow Androids / zoomed display settings).
          mainAxisExtent: 112,
          children: [
            _ActionTile(
              icon: Icons.qr_code_2_outlined,
              label: 'Take attendance',
              color: t.primary,
              onTap: () => context.push('/attendance'),
            ),
            _ActionTile(
              icon: Icons.podcasts,
              label: 'Start live class',
              color: t.statusAbsent,
              onTap: () => context.push('/attendance'),
            ),
            _ActionTile(
              icon: Icons.note_add_outlined,
              label: 'New note',
              color: t.secondary,
              onTap: () => context.push('/teacher-dashboard'),
            ),
            _ActionTile(
              icon: Icons.wifi_tethering_outlined,
              label: 'Offline exam',
              color: t.statusLate,
              onTap: () => context.push('/offline-exam'),
            ),
            _ActionTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Create IAM',
              color: t.primaryPressed,
              onTap: () => context.push('/create-im'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        if (sections.isEmpty)
          NexusSectionHeader(
            title: 'Your sections',
            subtitle:
                'Create a section from the Classroom tab to start classes.',
            spaceAbove: 0,
          )
        else ...[
          NexusSectionHeader(title: 'Your sections', spaceAbove: 0),
          NexusCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < sections.length; i++)
                  ListTile(
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: Text(
                      (sections[i] as Map<String, dynamic>)['label']
                              as String? ??
                          '',
                    ),
                    subtitle: Text(
                      '${(sections[i] as Map<String, dynamic>)['gradeLevel'] ?? ''}'
                      '${(sections[i] as Map<String, dynamic>)['subject'] != null ? ' · ${(sections[i] as Map<String, dynamic>)['subject']}' : ''}'
                      ' · ${(sections[i] as Map<String, dynamic>)['studentCount'] ?? 0} students',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/attendance'),
                  ),
              ],
            ),
          ),
        ],
        if (recentLive.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          NexusSectionHeader(title: 'Recent live classes', spaceAbove: 0),
          NexusCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recentLive.length; i++)
                  ListTile(
                    leading: const Icon(Icons.podcasts),
                    title: Text(
                      (recentLive[i] as Map<String, dynamic>)['title']
                              as String? ??
                          '',
                    ),
                    subtitle: Text(
                      '${(recentLive[i] as Map<String, dynamic>)['sectionLabel'] ?? ''} · '
                      '${_formatDate((recentLive[i] as Map<String, dynamic>)['startedAt'] as String?)}',
                    ),
                    onTap: () => context.push('/attendance'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    final t = context.tokens;
    return NexusCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge?.copyWith(color: t.ink),
          ),
        ],
      ),
    );
  }
}
