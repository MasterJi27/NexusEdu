import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/location_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/features/attendance/data/attendance_hotspot.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/qr_scanner_screen.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/teacher_attendance_screen.dart'
    show inviteCodeFromPayload;
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

/// Student side of attendance: enter the rotating code the teacher is
/// showing the class. The real fraud guard is server-side (the code is
/// short-lived and HMAC-verified, and a student can only mark themselves
/// once per session) — this screen just has to make the honest path fast.
class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  bool _isLoading = true;
  List<dynamic> _openSessions = [];
  Map<String, dynamic>? _selectedSession;
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _successStatus;

  Map<String, dynamic>? _history;
  List<dynamic> _tasks = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTasks();
    _loadNotifications();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final tasks = await SecureApiService().getClassroomTasks();
    if (!mounted) return;
    setState(() => _tasks = tasks);
  }

  Future<void> _loadNotifications() async {
    final result = await SecureApiService().getNotifications();
    if (!mounted) return;
    setState(() => _unreadNotifications = result['unreadCount'] as int? ?? 0);
  }

  Future<void> _toggleTask(Map<String, dynamic> task, bool done) async {
    final newStatus = done ? 'done' : 'pending';
    final index = _tasks.indexWhere((t) => (t as Map)['id'] == task['id']);
    if (index == -1) return;
    setState(() {
      _tasks[index] = {...task, 'myStatus': newStatus};
    });
    await SecureApiService().submitClassTask(task['id'] as String, status: newStatus);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final api = SecureApiService();
    if (api.isLoggedIn) {
      final sessions = await api.getMyOpenAttendanceSessions();
      final history = await api.getMyAttendanceHistory();
      if (!mounted) return;
      setState(() {
        _openSessions = sessions;
        _selectedSession = sessions.isNotEmpty
            ? Map<String, dynamic>.from(sessions.first as Map)
            : null;
        _history = history['records'] != null ? history : null;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanAndJoin() async {
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (!mounted || raw == null) return;
    final inviteCode = inviteCodeFromPayload(raw);
    if (inviteCode == null) {
      setState(() => _error = 'That QR is not a Nexus Edu classroom invite.');
      return;
    }
    await _joinWithCode(inviteCode);
  }

  Future<void> _joinWithCode(String inviteCode) async {
    setState(() {
      _submitting = true;
      _error = null;
      _successStatus = null;
    });
    final result = await SecureApiService().joinSectionByInviteResult(inviteCode);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!handleResultError(context, result)) {
      setState(() => _error = (result as Failure).message);
      return;
    }
    final data = (result as Success<Map<String, dynamic>>).data;
    final section = data['section'];
    final label = section is Map
        ? (section['label']?.toString() ?? 'the classroom')
        : 'the classroom';
    showSuccessSnackBar(context, 'You joined $label.');
    _load();
  }

  void _showJoinSheet() {
    final codeController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            MediaQuery.of(sheetContext).viewInsets.bottom + AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Join a classroom', style: sheetContext.text.headlineSmall),
              const SizedBox(height: AppSpace.xxs),
              Text(
                'Scan the QR your teacher shows, or type the 6-character invite code.',
                style: sheetContext.text.bodySmall?.copyWith(
                  color: sheetContext.tokens.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              NexusTextField(
                controller: codeController,
                label: 'Invite code',
                hint: 'e.g. K7M2PX',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _joinFromSheet(codeController),
              ),
              const SizedBox(height: AppSpace.sm),
              NexusButton(
                label: 'Scan QR',
                icon: Icons.qr_code_scanner,
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _scanAndJoin();
                },
              ),
              const SizedBox(height: AppSpace.sm),
              NexusButton(
                label: 'Join with code',
                onPressed: () => _joinFromSheet(codeController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _joinFromSheet(TextEditingController controller) {
    final code = controller.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z2-9]{6}$').hasMatch(code)) {
      showErrorSnackBar(context, 'Enter the 6-character invite code.');
      return;
    }
    Navigator.of(context).pop();
    _joinWithCode(code);
  }

  Future<void> _joinHotspot() async {
    final hostController = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join teacher hotspot'),
        content: NexusTextField(
          controller: hostController,
          label: 'Teacher hotspot IP',
          hint: '192.168.0.1',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Join',
            onPressed: () =>
                Navigator.pop(dialogContext, hostController.text.trim()),
          ),
        ],
      ),
    );
    hostController.dispose();
    if (!mounted || host == null || host.isEmpty) return;
    final session = await AttendanceHotspotClient().fetchSession(host, 8788);
    if (!mounted) return;
    if (session == null) {
      showErrorSnackBar(context, 'Could not reach the teacher. Check the IP and hotspot.');
      return;
    }
    _showHotspotSheet(session, host: host);
  }

  Future<void> _scanBleHotspot() async {
    final session = await AttendanceBleClient().fetchSession();
    if (!mounted) return;
    if (session == null) {
      showErrorSnackBar(
        context,
        'No teacher beacon found nearby. Make sure Bluetooth is on and the teacher is broadcasting.',
      );
      return;
    }
    _showHotspotSheet(session);
  }

  /// Peer-to-peer mark: lands on the teacher's phone and syncs to the
  /// server when they come back online. The teacher's device pre-checks the
  /// geo-fence; the server re-checks at sync.
  void _showHotspotSheet(AttendanceHotspotSession session, {String? host}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<(double? distance, bool? mocked)> position = () async {
            final fix = await LocationService.getCurrentPosition();
            if (fix == null || !session.isFenced) return (null, fix?.isMocked);
            return (
              distanceMetersBetween(
                session.lat!,
                session.lng!,
                fix.lat,
                fix.lng,
              ),
              fix.isMocked,
            );
          }();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    session.teacherName,
                    style: sheetContext.text.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    '${session.subject} · mark via teacher hotspot',
                    style: sheetContext.text.bodySmall?.copyWith(
                      color: sheetContext.tokens.inkMuted,
                    ),
                  ),
                  if (session.code.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    NexusCard(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      child: Text(
                        'Code: ${session.code} (or type it above to mark directly)',
                        style: sheetContext.typeExtras.bodyStrong.copyWith(
                          color: sheetContext.tokens.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  FutureBuilder<(double?, bool?)>(
                    future: position,
                    builder: (ctx, snapshot) {
                      final distance = snapshot.data?.$1;
                      if (session.isFenced && distance != null) {
                        return Row(
                          children: [
                            Icon(
                              distance <= 95
                                  ? Icons.location_on_outlined
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: distance <= 95
                                  ? ctx.tokens.statusPresent
                                  : ctx.tokens.statusAbsent,
                            ),
                            const SizedBox(width: AppSpace.xxs),
                            Expanded(
                              child: Text(
                                distance <= 95
                                    ? 'You\'re about ${distance.round()}m from the classroom.'
                                    : 'You look ${distance.round()}m away — the classroom check may reject this.',
                                style: ctx.text.bodySmall?.copyWith(
                                  color: distance <= 95
                                      ? ctx.tokens.inkMuted
                                      : ctx.tokens.statusAbsent,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Text(
                        session.isFenced
                            ? 'Reading your location…'
                            : 'This session has no location pin.',
                        style: ctx.text.bodySmall?.copyWith(
                          color: ctx.tokens.inkFaint,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.md),
                  NexusButton(
                    label: 'Mark via teacher',
                    icon: Icons.how_to_reg_outlined,
                    isLoading: _submitting,
                    onPressed: _submitting
                        ? null
                        : () => _submitViaHotspot(sheetContext, session, host),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitViaHotspot(
    BuildContext sheetContext,
    AttendanceHotspotSession session,
    String? host,
  ) async {
    final userId = SecureApiService().userId;
    if (userId == null) {
      showErrorSnackBar(sheetContext, 'Sign in to mark attendance.');
      return;
    }
    setState(() => _submitting = true);
    final location = await LocationService.getCurrentPosition();
    final mark = AttendanceHotspotMark(
      studentId: userId,
      clientMarkedAt: DateTime.now(),
      lat: location?.lat,
      lng: location?.lng,
      isMocked: location?.isMocked,
    );
    final result = host != null
        ? await AttendanceHotspotClient().submitMark(host, 8788, mark)
        : await AttendanceBleClient().submitMark(mark);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!sheetContext.mounted) return;
    if (result == null) {
      showErrorSnackBar(sheetContext, 'Could not reach the teacher. Stay near them and try again.');
      return;
    }
    if (showMapErrorIfAny(sheetContext, result)) {
      return;
    }
    Navigator.pop(sheetContext);
    showSuccessSnackBar(
      context,
      'Marked! ${session.teacherName} will sync it when online.',
    );
    _load();
  }

  Future<void> _submit() async {
    final session = _selectedSession;
    if (session == null) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(
        () => _error = 'Enter the 6-digit code your teacher is showing.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _successStatus = null;
    });

    // Attach the device position when we can get one. When we can't, send
    // without it and let the server decide: a fenced session will refuse
    // with a clear message, an unfenced one marks normally.
    var location = await LocationService.getCurrentPosition();
    if (!mounted) return;

    final result = await SecureApiService().markAttendanceResult(
      session['sessionId'] as String,
      code,
      lat: location?.lat,
      lng: location?.lng,
      isMocked: location?.isMocked,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!handleResultError(context, result)) {
      setState(() => _error = (result as Failure).message);
      return;
    }
    final data = (result as Success<Map<String, dynamic>>).data;
    setState(() => _successStatus = data['status'] as String? ?? 'present');
    _codeController.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          if (SecureApiService().isLoggedIn)
            IconButton(
              tooltip: 'Notifications',
              onPressed: _showNotifications,
              icon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text('$_unreadNotifications'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          if (SecureApiService().isLoggedIn)
            IconButton(
              tooltip: 'Scan classroom QR',
              onPressed: _submitting ? null : _scanAndJoin,
              icon: const Icon(Icons.qr_code_scanner),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: NexusStateView.loading(rows: 3),
              )
            : !SecureApiService().isLoggedIn
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: NexusStateView.empty(
                    title: 'Sign in to mark attendance.',
                    icon: Icons.lock_outline,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.lg),
                children: [
                  NexusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wifi_tethering,
                              size: 18,
                              color: t.statusPresent,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                'Teacher hotspot (no internet needed)',
                                style: context.text.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          'Join the teacher\'s hotspot or Bluetooth beacon to mark on their phone. It syncs to the server when they\'re online.',
                          style: context.text.bodySmall?.copyWith(
                            color: t.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              child: NexusButton(
                                label: 'Join hotspot',
                                icon: Icons.lan_outlined,
                                size: NexusButtonSize.small,
                                onPressed: _submitting ? null : _joinHotspot,
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: NexusButton(
                                label: 'Scan beacon',
                                icon: Icons.bluetooth_searching,
                                size: NexusButtonSize.small,
                                onPressed: _submitting ? null : _scanBleHotspot,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (_openSessions.isEmpty) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.xl,
                        ),
                        child: NexusStateView.empty(
                          title: 'No attendance open right now',
                          description:
                              'Your teacher hasn\'t started an attendance session for any of your sections yet.',
                          icon: Icons.event_busy_outlined,
                          actionLabel: 'Check again',
                          onAction: _load,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      NexusBanner(
                        message: _error!,
                        kind: NexusBannerKind.error,
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    NexusButton(
                      label: 'Join a classroom',
                      icon: Icons.qr_code_scanner,
                      fullWidth: true,
                      onPressed: _submitting ? null : _showJoinSheet,
                    ),
                  ] else ...[
                    if (_openSessions.length > 1)
                      _buildSessionPicker()
                    else
                      NexusCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedSession!['sectionLabel'] as String? ??
                                  '',
                              style: context.text.titleSmall,
                            ),
                            Text(
                              _selectedSession!['subject'] as String? ?? '',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpace.md),
                    NexusTextField(
                      controller: _codeController,
                      label: 'Enter the 6-digit code',
                      keyboardType: TextInputType.number,
                      maxLines: 1,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: t.inkFaint,
                        ),
                        const SizedBox(width: AppSpace.xxs),
                        Expanded(
                          child: Text(
                            'Your device location is verified against the classroom when the teacher pins one.',
                            style: context.text.bodySmall?.copyWith(
                              color: t.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      NexusBanner(
                        message: _error!,
                        kind: NexusBannerKind.error,
                      ),
                    ],
                    if (_successStatus != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      NexusBanner(
                        message:
                            "You're marked ${_successStatus!} for this session.",
                        kind: NexusBannerKind.info,
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    NexusButton(
                      label: 'Mark attendance',
                      fullWidth: true,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                  if (_tasks.isNotEmpty) ...[
                    NexusSectionHeader(title: 'My class tasks'),
                    for (final raw in _tasks)
                      _buildTaskRow(Map<String, dynamic>.from(raw as Map)),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  if (_history != null) ...[
                    NexusSectionHeader(title: 'Your attendance, last 30 days'),
                    _buildHistorySummary(t),
                    const SizedBox(height: AppSpace.sm),
                    for (final raw in (_history!['records'] as List).take(10))
                      _buildHistoryRow(Map<String, dynamic>.from(raw as Map)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildSessionPicker() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which class?', style: context.text.labelMedium),
        const SizedBox(height: AppSpace.xs),
        for (final raw in _openSessions) _buildSessionOption(t, raw as Map),
      ],
    );
  }

  Widget _buildSessionOption(AppTokens t, Map session) {
    final isSelected = _selectedSession?['sessionId'] == session['sessionId'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: isSelected ? t.primary : t.inkFaint,
        ),
        title: Text('${session['sectionLabel']} · ${session['subject']}'),
        onTap: () => setState(
          () => _selectedSession = Map<String, dynamic>.from(session),
        ),
      ),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task) {
    final t = context.tokens;
    final done = task['myStatus'] == 'done';
    final dueDate = task['dueDate'];
    final section = task['section'] as Map?;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.xs),
      padding: EdgeInsets.zero,
      child: CheckboxListTile(
        value: done,
        activeColor: t.statusPresent,
        onChanged: (v) => _toggleTask(task, v ?? false),
        title: Text(
          task['title'] as String? ?? '',
          style: context.text.titleSmall?.copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? t.inkMuted : t.ink,
          ),
        ),
        subtitle: Text(
          [
            if (section?['label'] != null) section!['label'].toString(),
            if (task['points'] != null && (task['points'] as int) > 0)
              '${task['points']} points',
            if (dueDate != null)
              'due ${_formatDueDate(DateTime.parse(dueDate as String).toLocal())}',
          ].join(' · '),
          style: context.text.bodySmall?.copyWith(color: t.inkMuted),
        ),
        secondary: Icon(
          done ? Icons.task_alt : Icons.radio_button_unchecked,
          color: done ? t.statusPresent : t.inkFaint,
        ),
      ),
    );
  }

  String _formatDueDate(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(due.year, due.month, due.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    if (diff == -1) return 'yesterday';
    return '${due.day}/${due.month}';
  }

  Future<void> _showNotifications() async {
    final result = await SecureApiService().getNotifications();
    if (!mounted) return;
    final items = (result['items'] as List?) ?? const <dynamic>[];
    setState(() => _unreadNotifications = result['unreadCount'] as int? ?? 0);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: sheetContext.text.headlineSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await SecureApiService().markNotificationsRead();
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        _loadNotifications();
                      },
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.xl),
                      child: NexusStateView.empty(
                        title: 'Nothing yet',
                        description:
                            'Syllabus notes and tasks from your teachers will show up here.',
                        icon: Icons.notifications_none,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, index) {
                      final item = Map<String, dynamic>.from(items[index] as Map);
                      final read = item['readAt'] != null;
                      final type = item['type'] as String? ?? '';
                      return ListTile(
                        leading: Icon(
                          type == 'class_task'
                              ? Icons.task_alt
                              : Icons.menu_book_outlined,
                          color: read
                              ? ctx.tokens.inkFaint
                              : ctx.tokens.primary,
                        ),
                        title: Text(
                          item['title'] as String? ?? '',
                          style: ctx.text.titleSmall?.copyWith(
                            fontWeight: read ? FontWeight.w400 : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(item['body'] as String? ?? ''),
                        trailing: read
                            ? null
                            : Icon(
                                Icons.circle,
                                size: 10,
                                color: ctx.tokens.primary,
                              ),
                        onTap: () async {
                          await SecureApiService().markNotificationsRead(
                            id: item['id'] as String,
                          );
                          _loadNotifications();
                          final link = item['link'] as String?;
                          if (link != null && ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySummary(AppTokens t) {
    final summary = Map<String, dynamic>.from(_history!['summary'] as Map);
    final pct = summary['percentage'] as int?;
    return NexusCard(
      child: Row(
        children: [
          Text(
            pct != null ? '$pct%' : '—',
            style: context.typeExtras.figureLg.copyWith(
              color: pct != null && pct < 75 ? t.statusAbsent : t.statusPresent,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              '${summary['present']} present out of ${summary['total']} sessions',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${record['section']} · ${record['subject']}',
              style: context.text.bodySmall,
            ),
          ),
          Text(
            record['status'] as String? ?? '',
            style: context.text.labelMedium?.copyWith(
              color: record['status'] == 'present'
                  ? context.tokens.statusPresent
                  : context.tokens.statusAbsent,
            ),
          ),
        ],
      ),
    );
  }
}
