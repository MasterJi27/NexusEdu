import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_list_row.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedClass;
  Set<String> _completedShorts = {};
  bool _isLoading = true;
  String _userName = 'Guest';
  String? _photoUrl;
  List<dynamic> _deviceSessions = [];
  List<dynamic> _linkRequests = [];
  bool _respondingToRequest = false;

  String? _orgName;
  String? _orgLogoUrl;
  String? _accentHex;

  /// Curated accent palette for the organization branding picker. Hex strings
  /// (not Color literals) — they travel to the server as data and get parsed
  /// by AppTheme.parseAccent.
  static const List<(String, String)> _accentPalette = [
    ('Navy', '#26377A'),
    ('Indigo', '#4F46E5'),
    ('Purple', '#7C4DFF'),
    ('Blue', '#2563EB'),
    ('Teal', '#0F766E'),
    ('Green', '#15803D'),
    ('Amber', '#B45309'),
    ('Rose', '#BE185D'),
    ('Crimson', '#B3261E'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    final completed = await LearnerProfileService.getCompletedShortIds();
    await GamificationService().load();

    final api = SecureApiService();
    String name = api.userName;
    String? photoUrl;
    if (api.isLoggedIn) {
      // The three server calls run in parallel instead of serializing the
      // whole screen behind one round-trip after another.
      final results = await Future.wait<dynamic>([
        api.getProfile(),
        api.getDeviceSessions(),
        if (api.role == 'student')
          api.getLinkRequests()
        else
          Future.value(const []),
      ]);
      final profile = results[0];
      if (profile is Map && profile['error'] == null) {
        name = (profile['name'] as String?)?.trim().isNotEmpty == true
            ? profile['name'] as String
            : name;
        photoUrl = profile['photoUrl'] as String?;
        _orgName = profile['organizationName'] as String?;
        _orgLogoUrl = profile['orgLogoUrl'] as String?;
        _accentHex = profile['accentColor'] as String?;
      }
      _deviceSessions = results[1] is List
          ? results[1] as List
          : _deviceSessions;
      if (api.role == 'student') {
        _linkRequests = results[2] is List ? results[2] as List : _linkRequests;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedClass = selectedClass;
      _completedShorts = completed;
      _userName = name;
      _photoUrl = photoUrl;
      _isLoading = false;
    });
  }

  Future<void> _respondToRequest(String requestId, bool approve) async {
    setState(() => _respondingToRequest = true);
    final result = await SecureApiService().respondToLinkRequest(
      requestId,
      approve,
    );
    if (!mounted) return;
    setState(() => _respondingToRequest = false);
    if (showMapErrorIfAny(context, result)) {
      return;
    }
    setState(() {
      _linkRequests = _linkRequests
          .where((r) => (r as Map)['id'] != requestId)
          .toList();
    });
    showSuccessSnackBar(context, approve ? 'Link approved.' : 'Link request declined.');
  }

  bool get _aiReady => SecureApiService().isLoggedIn;

  bool get _canEditOrg {
    final role = SecureApiService().role;
    return role == 'teacher' ||
        role == 'admin' ||
        role == 'im' ||
        role == 'hod';
  }

  bool get _hasOrgData {
    return (_orgName?.isNotEmpty == true) ||
        (_orgLogoUrl?.isNotEmpty == true) ||
        (_accentHex?.isNotEmpty == true) ||
        (SecureApiService().organizationName?.isNotEmpty == true) ||
        (SecureApiService().orgLogoUrl?.isNotEmpty == true) ||
        (SecureApiService().accentColorHex?.isNotEmpty == true);
  }

  void _showOrgEditDenied() {
    _showSnack('Only teachers/admins can edit organization');
  }

  void _showSnack(String message) {
    showErrorSnackBar(context, message);
  }

  Future<void> _showRenameDialog() async {
    if (!SecureApiService().isLoggedIn) {
      _showSnack('Sign in to edit your profile.');
      return;
    }
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(
        title: 'Edit name',
        hint: 'Your name',
        initial: _userName,
      ),
    );

    if (newName == null || newName.isEmpty || newName == _userName) return;
    if (!mounted) return;
    final result = await SecureApiService().updateProfile(name: newName);
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      return;
    } else {
      setState(() => _userName = newName);
      showSuccessSnackBar(context, 'Name updated.');
    }
  }

  Future<void> _changeAvatar() async {
    if (!SecureApiService().isLoggedIn) {
      _showSnack('Sign in to change your photo.');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    showSuccessSnackBar(context, 'Uploading photo...');
    final result = await SecureApiService().uploadAvatar(picked.path);
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      return;
    } else {
      setState(() => _photoUrl = result['photoUrl'] as String?);
      showSuccessSnackBar(context, 'Photo updated.');
    }
  }

  Future<void> _revokeDeviceSession(String sessionId) async {
    final result = await SecureApiService().revokeDeviceSessionResult(sessionId);
    if (!mounted) return;
    if (!handleResultError(context, result)) {
      return;
    }
    await _loadProfile();
  }

  void _showExamDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          AppSettings.instance.examDate ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final nameController = TextEditingController(
        text: AppSettings.instance.examName,
      );
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.tokens.surface,
          title: Text('Exam Name', style: ctx.text.titleLarge),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'e.g. JEE Main'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                AppSettings.instance.setExamDate(date, nameController.text);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Profile',
      actions: [
        IconButton(
          icon: Icon(Icons.leaderboard, color: t.secondary),
          onPressed: () => context.push('/leaderboard'),
          tooltip: 'Leaderboard',
        ),
        if (SecureApiService().isTeacher)
          IconButton(
            icon: Icon(Icons.co_present, color: t.primary),
            onPressed: () => context.push('/teacher-dashboard'),
            tooltip: 'Teacher Dashboard',
          )
        else
          IconButton(
            icon: Icon(Icons.meeting_room_outlined, color: t.primary),
            onPressed: () => context.go('/classroom'),
            tooltip: 'Classroom',
          ),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: t.inkMuted),
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
        ),
      ],
      body: _isLoading
          ? const NexusStateView.loading()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.lg,
                  AppSpace.xl,
                ),
                children: [
                  _buildProfileHeader(context),
                  const SizedBox(height: AppSpace.lg),
                  _buildExploreMenu(context),
                  if (SecureApiService().isLoggedIn &&
                      (_canEditOrg || _hasOrgData)) ...[
                    const SizedBox(height: AppSpace.lg),
                    _buildOrgBrandingCard(context),
                  ],
                  if (_linkRequests.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.lg),
                    _buildParentLinkRequestsCard(),
                  ],
                  if (SecureApiService().isLoggedIn) ...[
                    const SizedBox(height: AppSpace.lg),
                    _buildDeviceSessionsCard(),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  _buildStreakCard(),
                  const SizedBox(height: AppSpace.lg),
                  _buildClassCard(context),
                  const SizedBox(height: AppSpace.lg),
                  _buildStatsSection(context),
                  const SizedBox(height: AppSpace.lg),
                  _buildExamCountdownCard(),
                  const SizedBox(height: AppSpace.lg),
                  _buildCertificatesSection(context),
                  const SizedBox(height: AppSpace.lg),
                  _buildAchievementsSection(context),
                  if (SecureApiService().isLoggedIn) ...[
                    const SizedBox(height: AppSpace.xl),
                    _buildLogoutButton(context),
                  ] else ...[
                    const SizedBox(height: AppSpace.xl),
                    _buildGuestActions(context),
                  ],
                ],
              ),
            ),
    );
  }

  /// Guests get a sign-in path and a way back out to the welcome screen,
  /// instead of the logout button meant for real accounts.
  Widget _buildGuestActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusButton(
          label: 'Sign in',
          icon: Icons.login,
          fullWidth: true,
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: AppSpace.xs),
        TextButton(
          onPressed: () async {
            await AuthState.instance.logout();
            if (context.mounted) context.go('/welcome');
          },
          child: const Text('Exit guest mode'),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.primaryTintBorder, width: 2),
          ),
          child: GestureDetector(
            onTap: _changeAvatar,
            child: Stack(
              children: [
                // CachedNetworkImageProvider with mem cache for 1M scale; fallback to initial on error.
                CircleAvatar(
                  radius: 42,
                  backgroundColor: t.primaryTint,
                  foregroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(_photoUrl!, maxWidth: 168, maxHeight: 168)
                      : null,
                  onForegroundImageError:
                      (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? (_, _) {
                          // A dead avatar URL must not pin the header in an
                          // error state — fall back to the initial below.
                          setState(() => _photoUrl = null);
                        }
                      : null,
                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                      ? Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'G',
                          style: context.text.headlineLarge?.copyWith(
                            color: t.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: t.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 2),
                    ),
                    child: Icon(Icons.camera_alt, size: 14, color: t.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _userName,
                      style: context.text.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _showRenameDialog,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: t.inkMuted,
                    tooltip: 'Edit name',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  _buildStatusPill(
                    _selectedClass ?? 'Guest mode',
                    _selectedClass == null
                        ? Icons.person_outline
                        : Icons.school,
                    t.primary,
                  ),
                  _buildStatusPill(
                    _aiReady ? 'AI ready' : 'Sign in for AI',
                    _aiReady ? Icons.check_circle : Icons.key_off,
                    _aiReady ? t.statusPresent : t.statusAbsent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Quick-links menu: the surfaces people come to Profile for, one tap away.
  Widget _buildExploreMenu(BuildContext context) {
    final t = context.tokens;
    final entries = [
      (Icons.bolt_outlined, 'AI usage', '/ai-usage'),
      (Icons.grid_view_outlined, 'All features', '/features'),
    ];
    return NexusCard(
      child: Column(
        children: [
          for (final (index, entry) in entries.indexed) ...[
            NexusListRow(
              leadingIcon: entry.$1,
              title: entry.$2,
              trailing: Icon(Icons.chevron_right, color: t.inkFaint),
              onTap: () => context.push(entry.$3),
            ),
            if (index < entries.length - 1)
              Divider(height: 1, color: t.border.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }

  /// Organization branding: the school/college/institute identity shown on
  /// teacher surfaces and as the live-class watermark. All logged-in users can
  /// view; only teacher/admin/im/hod can edit (server-enforced, client mirrors).
  Widget _buildOrgBrandingCard(BuildContext context) {
    final t = context.tokens;
    final effectiveName = _orgName?.isNotEmpty == true
        ? _orgName
        : SecureApiService().organizationName;
    final effectiveLogo = _orgLogoUrl?.isNotEmpty == true
        ? _orgLogoUrl
        : SecureApiService().orgLogoUrl;
    final effectiveAccent = _accentHex ?? SecureApiService().accentColorHex;
    final isViewer = !_canEditOrg;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.md,
              AppSpace.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.business_outlined, color: t.primary),
                const SizedBox(width: AppSpace.xs),
                Text(
                  _canEditOrg ? 'Organization & branding' : 'Organization',
                  style: context.text.titleSmall,
                ),
                if (isViewer) ...[
                  const SizedBox(width: AppSpace.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: AppRadius.brPill,
                      border: Border.all(color: t.border),
                    ),
                    child: Text(
                      'View only',
                      style: context.text.labelSmall?.copyWith(
                        color: t.inkMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          NexusListRow(
            leadingIcon: Icons.image_outlined,
            title: _canEditOrg
                ? (effectiveName?.isNotEmpty == true
                      ? 'Change logo'
                      : 'Add logo')
                : 'Logo',
            subtitle: _canEditOrg
                ? 'Shown on dashboards and live classes'
                : (effectiveLogo?.isNotEmpty == true
                      ? 'Organization logo'
                      : 'No logo set'),
            onTap: _canEditOrg ? _changeOrgLogo : _showOrgEditDenied,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clear logo: backend has no DELETE /org-logo endpoint (only POST /org-logo to replace;
                // updateProfile does not accept orgLogoUrl). Show guidance until a delete endpoint exists.
                // TODO: add DELETE /api/users/org-logo and wire SecureApiService.clearOrgLogo() here.
                if (_canEditOrg && effectiveLogo?.isNotEmpty == true)
                  TextButton(
                    onPressed: _clearOrgLogo,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                effectiveLogo?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: AppRadius.brSm,
                        child: CachedNetworkImage(
                          imageUrl: effectiveLogo!,
                          width: 32,
                          height: 32,
                          memCacheWidth: 64,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => const SizedBox(width: 32, height: 32),
                          errorWidget: (c, u, e) =>
                              Icon(Icons.business_outlined, color: t.inkFaint),
                        ),
                      )
                    : Icon(
                        _canEditOrg
                            ? Icons.chevron_right
                            : Icons.visibility_outlined,
                        color: t.inkFaint,
                      ),
              ],
            ),
          ),
          NexusListRow(
            leadingIcon: Icons.badge_outlined,
            title: _canEditOrg
                ? (effectiveName?.isNotEmpty == true
                      ? 'Change name'
                      : 'Add name')
                : 'Name',
            subtitle: effectiveName?.isNotEmpty == true
                ? effectiveName
                : (_canEditOrg
                      ? 'e.g. Sunrise Public School'
                      : 'No organization set'),
            onTap: _canEditOrg ? _editOrgName : _showOrgEditDenied,
            trailing: Icon(
              _canEditOrg ? Icons.chevron_right : Icons.visibility_outlined,
              color: t.inkFaint,
            ),
          ),
          NexusListRow(
            leadingIcon: Icons.palette_outlined,
            title: 'Accent color',
            subtitle: _canEditOrg
                ? 'Applies to the whole app theme'
                : (effectiveAccent?.isNotEmpty == true
                      ? 'Organization theme color'
                      : 'Default theme'),
            onTap: _canEditOrg ? _pickAccentColor : _showOrgEditDenied,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        AppTheme.parseAccent(effectiveAccent) ??
                        context.tokens.primary,
                    border: Border.all(color: t.borderStrong),
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Icon(
                  _canEditOrg ? Icons.chevron_right : Icons.visibility_outlined,
                  color: t.inkFaint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeOrgLogo() async {
    if (!SecureApiService().isLoggedIn) return;
    if (!_canEditOrg) {
      _showOrgEditDenied();
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    showSuccessSnackBar(context, 'Uploading logo...');
    final result = await SecureApiService().uploadOrgLogo(picked.path);
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      return;
    } else {
      setState(() {
        _orgLogoUrl = result['orgLogoUrl'] as String?;
        _orgName = result['organizationName'] as String? ?? _orgName;
        _accentHex = result['accentColor'] as String? ?? _accentHex;
      });
      showSuccessSnackBar(context, 'Logo updated.');
    }
  }

  /// Clear logo action: backend has no delete endpoint for orgLogoUrl (only
  /// uploadOrgLogo POST to replace). updateProfile does not accept orgLogoUrl,
  /// so we cannot clear server-side. Show guidance; logo can be replaced by
  /// uploading a new one. When DELETE /api/users/org-logo is added, wire it
  /// here and sync via _orgLogoUrl = null + SecureApiService._syncOrgBranding.
  Future<void> _clearOrgLogo() async {
    if (!_canEditOrg) {
      _showOrgEditDenied();
      return;
    }
    // No backend clear endpoint — inform user that replacement is the current path.
    // TODO: implement SecureApiService.clearOrgLogo() -> DELETE /api/users/org-logo
    // and on success: setState(() => _orgLogoUrl = null) + _syncOrgBranding with null.
    if (!mounted) return;
    showErrorSnackBar(
      context,
      'Logo can be replaced by uploading a new one. Contact admin to clear.',
    );
  }

  Future<void> _editOrgName() async {
    if (!SecureApiService().isLoggedIn) return;
    if (!_canEditOrg) {
      _showOrgEditDenied();
      return;
    }
    final effectiveName = _orgName?.isNotEmpty == true
        ? _orgName!
        : (SecureApiService().organizationName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(
        title: 'Organization name',
        hint: 'e.g. Sunrise Public School',
        initial: effectiveName,
      ),
    );
    if (newName == null || !mounted) return;

    final result = await SecureApiService().updateProfile(
      organizationName: newName,
    );
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      return;
    } else {
      setState(() => _orgName = newName.isEmpty ? null : newName);
      showSuccessSnackBar(context, 'Organization name updated.');
    }
  }

  Future<void> _pickAccentColor() async {
    if (!SecureApiService().isLoggedIn) return;
    if (!_canEditOrg) {
      _showOrgEditDenied();
      return;
    }
    final effectiveAccent = _accentHex ?? SecureApiService().accentColorHex;
    final current = AppTheme.parseAccent(effectiveAccent);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.tokens.surface,
        title: Text('Accent color', style: ctx.text.titleLarge),
        content: Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.md,
          children: [
            for (final (label, hex) in _accentPalette)
              Tooltip(
                message: label,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(ctx, hex),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.parseAccent(hex),
                      border: Border.all(
                        color: current != null && hex == effectiveAccent
                            ? ctx.tokens.ink
                            : ctx.tokens.borderStrong,
                        width: current != null && hex == effectiveAccent
                            ? 3
                            : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    // picked == '' is the Reset sentinel: send '' so backend clears accentColor (stores ''/null).
    // Sending null would be a no-op (field omitted) and would not clear server state.
    // SecureApiService.updateProfile allows '' for reset (client regex skips empty).
    final result = await SecureApiService().updateProfile(accentColor: picked);
    if (!mounted) return;
    if (showMapErrorIfAny(context, result)) {
      return;
    } else {
      setState(() => _accentHex = picked.isEmpty ? null : picked);
      showSuccessSnackBar(
        context,
        picked.isEmpty
            ? 'Accent reset to default.'
            : 'Accent updated. Theme applies across the app.',
      );
    }
  }

  Widget _buildStreakCard() {
    final t = context.tokens;
    final settings = AppSettings.instance;
    final streak = settings.streak;
    return NexusCard(
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: t.secondaryTint,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(
              Icons.local_fire_department,
              color: t.secondary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak Day Streak',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  streak == 0
                      ? 'Start studying today!'
                      : settings.streakSaverUsed
                      ? 'Streak shield saved it once — study today or it resets.'
                      : streak >= 7
                      ? 'Amazing consistency!'
                      : 'Keep it going!',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '$streak',
            style: context.typeExtras.figureLg.copyWith(color: t.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSessionsCard() {
    final t = context.tokens;
    final activeCount = _deviceSessions.length;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Icons.devices, color: t.primary),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active devices', style: context.text.titleSmall),
                    Text(
                      '$activeCount of 2 devices in use',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_deviceSessions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            for (final raw in _deviceSessions.take(2))
              _buildDeviceSessionTile(Map<String, dynamic>.from(raw as Map)),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceSessionTile(Map<String, dynamic> session) {
    final t = context.tokens;
    final isCurrent = session['isCurrent'] == true;
    final name = session['deviceName']?.toString().trim();
    final title = name == null || name.isEmpty ? 'Unknown device' : name;
    final lastSeen = session['lastSeenAt']?.toString();
    final lastSeenDate = lastSeen?.substring(
      0,
      lastSeen.length < 10 ? lastSeen.length : 10,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isCurrent ? Icons.phone_iphone : Icons.devices_other,
        color: isCurrent ? t.statusPresent : t.inkMuted,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        isCurrent
            ? 'This device'
            : lastSeen == null
            ? 'Last seen unknown'
            : 'Last seen $lastSeenDate',
      ),
      trailing: isCurrent
          ? Chip(label: Text('Current'))
          : IconButton(
              tooltip: 'Remove device',
              onPressed: () => _revokeDeviceSession(session['id'] as String),
              icon: Icon(Icons.logout, color: t.statusAbsent),
            ),
    );
  }

  /// A parent asked to link to this account. Nothing about this student is
  /// visible to that parent until they explicitly approve it here — see the
  /// consent flow in backend/src/routes/parent.ts.
  Widget _buildParentLinkRequestsCard() {
    final t = context.tokens;
    return NexusCard(
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom, color: t.primary, size: 22),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  _linkRequests.length == 1
                      ? 'A parent wants to link to your account'
                      : '${_linkRequests.length} parents want to link to your account',
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Approving shares your name, grade, XP, streak, and weak/strong '
            'subjects with them. You can unlink at any time from their side.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpace.sm),
          for (final raw in _linkRequests)
            _buildLinkRequestRow(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _buildLinkRequestRow(Map<String, dynamic> request) {
    final parent = (request['parent'] as Map?) ?? const {};
    final name = parent['name']?.toString() ?? 'A parent';
    final requestId = request['id'] as String;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Row(
        children: [
          Expanded(child: Text(name, style: context.typeExtras.bodyStrong)),
          IconButton(
            tooltip: 'Decline',
            onPressed: _respondingToRequest
                ? null
                : () => _respondToRequest(requestId, false),
            icon: Icon(Icons.close, color: context.tokens.statusAbsent),
          ),
          NexusButton(
            label: 'Approve',
            size: NexusButtonSize.small,
            isLoading: _respondingToRequest,
            onPressed: _respondingToRequest
                ? null
                : () => _respondToRequest(requestId, true),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCountdownCard() {
    final t = context.tokens;
    final examDate = AppSettings.instance.examDate;
    final examName = AppSettings.instance.examName;
    if (examDate == null) {
      return NexusCard(
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(Icons.event, color: t.primary),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Exam Target', style: context.text.titleSmall),
                  Text(
                    'Add a countdown to stay motivated',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            NexusButton(
              label: 'Set Date',
              onPressed: _showExamDatePicker,
              variant: NexusButtonVariant.secondary,
              size: NexusButtonSize.small,
            ),
          ],
        ),
      );
    }

    final daysLeft = examDate.difference(DateTime.now()).inDays;
    final color = daysLeft <= 7
        ? t.statusAbsent
        : daysLeft <= 30
        ? t.secondary
        : t.statusPresent;

    return NexusCard(
      borderColor: color.withValues(alpha: 0.35),
      background: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Icons.event, color: color, size: 26),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  daysLeft <= 0 ? 'Today!' : '$daysLeft days remaining',
                  style: context.text.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$daysLeft',
                style: context.typeExtras.figureLg.copyWith(color: color),
              ),
              Text(
                'days',
                style: context.text.labelSmall?.copyWith(color: t.inkFaint),
              ),
            ],
          ),
          const SizedBox(width: AppSpace.xs),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => AppSettings.instance.clearExamDate(),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context) {
    final t = context.tokens;
    final subjects = LearningCatalog.subjectsFor(_selectedClass);
    final palette = [t.primary, t.secondary, t.ink, t.inkMuted];
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(
                  _selectedClass == null ? Icons.person_outline : Icons.school,
                  color: t.primary,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedClass ?? 'Guest learning',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      _selectedClass == null
                          ? 'Shorts will ask topic first.'
                          : '${subjects.length} subjects linked to Shorts.',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                for (final (index, subject) in subjects.indexed)
                  _buildStatusPill(
                    subject.name,
                    subject.icon,
                    palette[index % palette.length],
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: NexusButton(
                  label: 'Set class',
                  onPressed: () => context.push('/elearning-class'),
                  icon: Icons.tune,
                  variant: NexusButtonVariant.secondary,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: NexusButton(
                  label: 'Shorts',
                  onPressed: () => context.go('/feed'),
                  icon: Icons.smart_display,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final t = context.tokens;
    final earnedCerts = LearningCatalog.certificatesFor(
      selectedClass: _selectedClass,
      completedShorts: _completedShorts.length,
    ).where((c) => c.progress >= 1.0).length;
    final items = [
      _StatItem(
        '${AppSettings.instance.cachedNotes.length}',
        'Notes',
        Icons.document_scanner,
      ),
      _StatItem(
        '${AppSettings.instance.flashcardDecks.length}',
        'Flashcards',
        Icons.swipe,
      ),
      _StatItem(
        '${_completedShorts.length}',
        'Shorts Done',
        Icons.check_circle,
      ),
      _StatItem('$earnedCerts', 'Certificates', Icons.workspace_premium),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.74,
        crossAxisSpacing: AppSpace.xs,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(item.icon, color: t.primary),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(item.value, style: context.typeExtras.bodyStrong),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: t.inkFaint),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCertificatesSection(BuildContext context) {
    final t = context.tokens;
    final certificates = LearningCatalog.certificatesFor(
      selectedClass: _selectedClass,
      completedShorts: _completedShorts.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NexusSectionHeader(
          title: 'Certifications',
          actionLabel: 'Earn more',
          onAction: () => context.go('/feed'),
          spaceAbove: 0,
        ),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: certificates.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, index) {
              final c = certificates[index];
              return Container(
                width: 230,
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppRadius.brLg,
                  border: Border.all(color: t.primaryTintBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(c.icon, color: t.primary),
                        const Spacer(),
                        Text(
                          '${(c.progress * 100).round()}%',
                          style: context.typeExtras.bodyStrong.copyWith(
                            color: t.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      c.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                    const Spacer(),
                    LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 7,
                      borderRadius: AppRadius.brPill,
                      backgroundColor: t.surfaceAlt,
                      color: t.primary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        NexusCard(
          child: NexusListRow(
            leadingIcon: Icons.workspace_premium_outlined,
            title: 'Professional certifications',
            subtitle: 'Google Educator, Gemini & student programs',
            trailing: Icon(Icons.chevron_right, color: t.inkFaint),
            onTap: () => context.push('/certifications'),
          ),
        ),
      ],
    );
  }

  /// Real badges from [GamificationService] — computed from actual streak,
  /// quiz, and level data (`_checkBadges` in that service), not the four
  /// hardcoded badges (including an unearnable "Top 5% Thinker" percentile
  /// claim with no ranking logic behind it) every user used to see here
  /// regardless of their real activity.
  Widget _buildAchievementsSection(BuildContext context) {
    final t = context.tokens;
    final badges = GamificationService().badges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NexusSectionHeader(title: 'Badges', spaceAbove: 0),
        if (badges.isEmpty)
          Text(
            'Keep studying to earn your first badge.',
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          )
        else
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final badge in badges)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: t.primaryTint,
                    borderRadius: AppRadius.brPill,
                    border: Border.all(color: t.primaryTintBorder),
                  ),
                  child: Text(badge, style: context.text.labelMedium),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusPill(String label, IconData icon, Color color) {
    return AnimatedContainer(
      duration: AppMotion.tap,
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpace.xxs),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

Widget _buildLogoutButton(BuildContext context) {
  return NexusButton(
    label: 'Logout',
    icon: Icons.logout,
    variant: NexusButtonVariant.danger,
    fullWidth: true,
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.tokens.surface,
          title: Text('Logout', style: ctx.text.titleLarge),
          content: Text(
            'Are you sure you want to logout?',
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
      if (confirmed == true && context.mounted) {
        await AuthState.instance.logout();
        if (context.mounted) context.go('/welcome');
      }
    },
  );
}

/// Text prompt dialog that owns its TextEditingController. Disposing a
/// controller right after `showDialog` resolves is a race — the exit
/// transition is still running and the TextField can touch the controller
/// mid-animation, which trips "used after being disposed". Owning it here
/// disposes it exactly when the route unmounts, which is always safe.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.initial,
  });

  final String title;
  final String hint;
  final String initial;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.tokens.surface,
      title: Text(widget.title, style: context.text.titleLarge),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
