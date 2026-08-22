import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/features/classroom/presentation/screens/live_class_screen.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/org_brand_mark.dart';

/// Institute management home — shared by the Principal (admin), Institute
/// Managers (im) and HODs. What each one sees depends on their role and the
/// access a principal assigned to them:
///  - Live classes: every teacher broadcasting right now; tap any to watch.
///  - Create IM (admin/teacher/IM-with-access): mint an IM account + scope.
///  - Users & roles (admin/IM-with-access): promote teachers to HOD/IM.
class ManageHomeScreen extends StatefulWidget {
  const ManageHomeScreen({super.key});

  @override
  State<ManageHomeScreen> createState() => _ManageHomeScreenState();
}

class _ManageHomeScreenState extends State<ManageHomeScreen> {
  final _api = SecureApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _lives = [];
  bool _joining = false;

  String get _role => _api.role ?? 'im';

  bool get _canCreateIm => _role == 'admin' || _role == 'teacher';
  bool get _canManageUsers => _role == 'admin' || _role == 'im';
  bool get _canWatchLive => _role == 'admin' || _role == 'hod' || _role == 'im';

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
    // Populate org branding cache if empty so OrgBrandMark has data.
    // getProfile syncs organizationName/orgLogoUrl into SecureApiService.
    if ((_api.organizationName == null || _api.organizationName!.isEmpty) &&
        (_api.orgLogoUrl == null || _api.orgLogoUrl!.isEmpty) &&
        _api.isLoggedIn) {
      try {
        await _api.getProfile();
        if (!mounted) return;
      } catch (_) {
        // Branding is best-effort; live classes are the primary payload.
      }
    }
    final result = await _api.getInstituteLiveClassesResult();
    if (!mounted) return;
    if (!handleResultError(context, result)) {
      setState(() {
        _loading = false;
        _error = (result as Failure).message;
      });
      return;
    }
    final data = (result as Success<Map<String, dynamic>>).data;
    setState(() {
      _loading = false;
      _lives = data['items'] as List<dynamic>? ?? [];
    });
  }

  Future<void> _joinLive(Map<String, dynamic> live) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final result = await _api.getLiveClassTokenResult(live['id'] as String);
      if (!mounted) return;
      if (!handleResultError(context, result)) {
        return;
      }
      final data = (result as Success<Map<String, dynamic>>).data;
      final userId = _api.userId;
      if (userId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveClassScreen(
            liveSessionId: data['liveSessionId'] as String,
            appId: data['appId'] as String,
            token: data['token'] as String,
            channelName: data['channelName'] as String,
            userAccount: userId,
            isHost: false,
            recordingAllowed: data['recordingAllowed'] as bool? ?? false,
            title: data['title'] as String? ??
                live['title'] as String? ??
                'Live class',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildLiveCard(dynamic raw) {
    final live = Map<String, dynamic>.from(raw as Map);
    final startedAt = DateTime.tryParse(live['startedAt']?.toString() ?? '');
    return _LiveCard(
      live: live,
      timeAgo: startedAt == null ? '' : _timeAgo(startedAt),
      onJoin: _canWatchLive ? () => _joinLive(live) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final roleLabel = switch (_role) {
      'admin' => 'Principal',
      'im' => 'Institute Manager',
      'hod' => 'HOD',
      _ => 'Organization',
    };
    final orgName = _api.organizationName;
    final orgLogoUrl = _api.orgLogoUrl;
    final hasOrgBranding =
        (orgName?.isNotEmpty == true) || (orgLogoUrl?.isNotEmpty == true);
    return NexusScreen(
      title: 'Organization',
      titleWidget: hasOrgBranding
          ? OrgBrandMark(
              fallbackTitle: 'Organization',
              name: orgName,
              logoUrl: orgLogoUrl,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_outlined, color: t.primary),
                const SizedBox(width: AppSpace.sm),
                const Flexible(
                  child: Text('Organization', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
      actions: [
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.person_outline),
          onPressed: () => context.go('/profile'),
        ),
      ],
      onRefresh: _load,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: AppSpace.pageH,
          children: [
            _RoleChip(label: roleLabel, role: _role),
            const SizedBox(height: AppSpace.sm),
            OrgBrandMark(
              fallbackTitle: 'Organization',
              name: orgName,
              logoUrl: orgLogoUrl,
            ),
            const SizedBox(height: AppSpace.md),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else ...[
              _SectionHeader(
                icon: Icons.record_voice_over_outlined,
                title: 'Live classes now',
                trailing: Text(
                  '${_lives.length}',
                  style: context.text.labelMedium?.copyWith(color: t.inkMuted),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              if (_lives.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.videocam_off_outlined, color: t.inkFaint, size: 32),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'No teacher is live right now.',
                        style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                      ),
                    ],
                  ),
                )
              else
                for (final raw in _lives) ...[
                  _buildLiveCard(raw),
                  const SizedBox(height: AppSpace.sm),
                ],
              const SizedBox(height: AppSpace.lg),
              if (_canCreateIm) ...[
                _SectionHeader(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Institute Manager accounts',
                ),
                const SizedBox(height: AppSpace.sm),
                _ActionCard(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Create Institute Manager account',
                  subtitle:
                      'Make an Institute Manager with a specific access scope and hand over the credentials.',
                  onTap: () => context.push('/create-im'),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              if (_canManageUsers) ...[
                _SectionHeader(
                  icon: Icons.group_outlined,
                  title: 'Users & roles',
                ),
                const SizedBox(height: AppSpace.sm),
                _ActionCard(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Assign HOD / Institute Manager roles',
                  subtitle:
                      'Search any account and promote them to HOD or Institute Manager, or change their role.',
                  onTap: () => context.push('/manage-users'),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              const SizedBox(height: AppSpace.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.role});
  final String label;
  final String role;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
        decoration: BoxDecoration(
          color: role == 'admin' ? t.secondaryFill : t.primaryTint,
          borderRadius: AppRadius.brPill,
        ),
        child: Text(
          '$label account',
          style: context.text.labelMedium?.copyWith(
            color: role == 'admin' ? t.secondary : t.primary,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: t.primary),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(title, style: context.text.titleMedium),
        ),
        if (trailing != null) ?trailing,
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live, required this.timeAgo, this.onJoin});
  final Map<String, dynamic> live;
  final String timeAgo;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final teacher = live['teacher'] as Map<String, dynamic>?;
    final section = live['section'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.primaryTint, borderRadius: AppRadius.brSm),
            child: Icon(Icons.videocam_outlined, color: t.primary),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live['title']?.toString() ?? 'Live class',
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${teacher?['name']?.toString() ?? 'Teacher'} · ${section?['label']?.toString() ?? 'Class'}',
                  style: context.text.bodySmall?.copyWith(color: t.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: t.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Live · $timeAgo',
                      style: context.text.labelSmall?.copyWith(color: t.secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onJoin != null)
            FilledButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Watch'),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.primaryTint, borderRadius: AppRadius.brSm),
                child: Icon(icon, color: t.primary),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(color: t.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: AppRadius.brMd),
      child: Column(
        children: [
          Text(message, style: context.text.bodyMedium?.copyWith(color: t.inkMuted)),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}