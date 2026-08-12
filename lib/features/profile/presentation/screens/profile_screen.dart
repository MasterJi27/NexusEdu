import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_list_row.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _earnedCerts = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    final completed = await LearnerProfileService.getCompletedShortIds();

    final api = SecureApiService();
    String name = api.userName;
    String? photoUrl;
    if (api.isLoggedIn) {
      // The three server calls run in parallel instead of serializing the
      // whole screen behind one round-trip after another.
      final results = await Future.wait<dynamic>([
        api.getProfile(),
        api.getDeviceSessions(),
        if (api.role == 'student') api.getLinkRequests() else Future.value(const []),
      ]);
      final profile = results[0];
      if (profile is Map && profile['error'] == null) {
        name = (profile['name'] as String?)?.trim().isNotEmpty == true
            ? profile['name'] as String
            : name;
        photoUrl = profile['photoUrl'] as String?;
      }
      _deviceSessions = results[1] is List ? results[1] as List : _deviceSessions;
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
      _earnedCerts = 0;
      _isLoading = false;
    });
    _earnedCerts = await _earnedCertificates();
    if (mounted) setState(() {});
  }

  Future<void> _respondToRequest(String requestId, bool approve) async {
    setState(() => _respondingToRequest = true);
    final result = await SecureApiService().respondToLinkRequest(
      requestId,
      approve,
    );
    if (!mounted) return;
    setState(() => _respondingToRequest = false);
    if (result['error'] != null) {
      _showSnack(result['error'].toString());
      return;
    }
    setState(() {
      _linkRequests = _linkRequests
          .where((r) => (r as Map)['id'] != requestId)
          .toList();
    });
    _showSnack(approve ? 'Link approved.' : 'Link request declined.');
  }

  bool get _aiReady => SecureApiService().isLoggedIn;

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRenameDialog() async {
    if (!SecureApiService().isLoggedIn) {
      _showSnack('Sign in to edit your profile.');
      return;
    }
    final controller = TextEditingController(text: _userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.tokens.surface,
        title: Text('Edit name', style: ctx.text.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == _userName) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await SecureApiService().updateProfile(name: newName);
    if (!mounted) return;
    if (result['error'] != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
    } else {
      setState(() => _userName = newName);
      messenger.showSnackBar(const SnackBar(content: Text('Name updated.')));
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

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Uploading photo...')));
    final result = await SecureApiService().uploadAvatar(picked.path);
    if (!mounted) return;
    if (result['error'] != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
    } else {
      setState(() => _photoUrl = result['photoUrl'] as String?);
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated.')));
    }
  }

  Future<void> _revokeDeviceSession(String sessionId) async {
    final result = await SecureApiService().revokeDeviceSession(sessionId);
    if (!mounted) return;
    if (result['error'] != null) {
      _showSnack(result['error'].toString());
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
                CircleAvatar(
                  radius: 42,
                  backgroundColor: t.primaryTint,
                  foregroundImage:
                      (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? NetworkImage(_photoUrl!)
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
                  label: 'Change Class',
                  onPressed: () => context.push('/elearning-class'),
                  icon: Icons.tune,
                  variant: NexusButtonVariant.secondary,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: NexusButton(
                  label: 'Open Shorts',
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

  Future<int> _earnedCertificates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('cert_progress_') &&
              (prefs.getInt(k) ?? 0) >= 100,
        )
        .length;
  }

  Widget _buildStatsSection(BuildContext context) {
    final t = context.tokens;
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
      _StatItem('$_earnedCerts', 'Certificates', Icons.workspace_premium),
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
      ],
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NexusSectionHeader(title: 'Badges', spaceAbove: 0),
        Row(
          children: [
            _buildBadge(
              Icons.local_fire_department,
              '7 Day Streak',
              t.secondary,
            ),
            const SizedBox(width: AppSpace.md),
            _buildBadge(Icons.psychology, 'Top 5% Thinker', t.primary),
            const SizedBox(width: AppSpace.md),
            _buildBadge(Icons.speed, 'Speed Reader', t.inkMuted),
            const SizedBox(width: AppSpace.md),
            _buildBadge(Icons.verified, 'Certified Learner', t.ink),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.30), width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
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
        if (context.mounted) context.go('/login');
      }
    },
  );
}
