import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/sync_queue_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/features/attendance/data/attendance_hotspot.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/attendance_status_chip.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

/// Teacher's live view of one attendance session: the rotating code students
/// enter, and a roster reconciled against who has actually marked in.
///
/// Rotating the code server-side (not just re-displaying the same one) is
/// what makes a screenshot of it worthless once the window closes — see
/// backend/src/routes/attendance.ts. The live marked-count is what turns
/// "mark the whole class present without checking" into something a
/// teacher would actually notice.
///
/// When the classroom has no internet, the teacher can start the offline
/// hotspot: students on the phone's WiFi hotspot (or in BLE range) mark
/// peer-to-peer, marks queue on this device and flush to the backend batch
/// route when connectivity returns.
class AttendanceSessionScreen extends StatefulWidget {
  const AttendanceSessionScreen({
    super.key,
    required this.sessionId,
    required this.sectionLabel,
    required this.subject,
    required this.initialCode,
    required this.initialCodeTtlSeconds,
    this.lat,
    this.lng,
    this.radiusMeters,
  });

  final String sessionId;
  final String sectionLabel;
  final String subject;
  final String initialCode;
  final int initialCodeTtlSeconds;

  /// Optional geo-fence anchor the session was created with, forwarded to
  /// the offline hotspot so marks can be pre-checked peer-to-peer.
  final double? lat;
  final double? lng;
  final int? radiusMeters;

  @override
  State<AttendanceSessionScreen> createState() =>
      _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  late String _code;
  late int _secondsLeft;
  Timer? _tickTimer;
  Timer? _rosterTimer;

  bool _isLoadingRoster = true;
  List<dynamic> _roster = [];
  int _markedCount = 0;
  int _totalStudents = 0;
  bool _closing = false;
  bool _closed = false;

  AttendanceHotspotServer? _hotspot;
  AttendanceBleHost? _bleHost;
  int _hotspotMarks = 0;
  String? _localIps;
  bool _startingHotspot = false;
  bool _startingBle = false;
  bool _syncing = false;
  final List<StreamSubscription<AttendanceHotspotMark>> _markSubs = [];

  @override
  void initState() {
    super.initState();
    assert(widget.initialCode.isNotEmpty, 'initialCode must not be empty');
    assert(
      widget.initialCodeTtlSeconds > 0,
      'initialCodeTtlSeconds must be > 0',
    );
    _code = widget.initialCode;
    _secondsLeft = widget.initialCodeTtlSeconds;
    _loadRoster();
    // One tick a second to count the code down and re-fetch a fresh one once
    // it expires — the server, not this timer, decides when it actually
    // rotates.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _rosterTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadRoster(silent: true),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _rosterTimer?.cancel();
    for (final sub in _markSubs) {
      sub.cancel();
    }
    _hotspot?.stop();
    _bleHost?.stop();
    super.dispose();
  }

  AttendanceHotspotSession _hotspotSession() => AttendanceHotspotSession(
    sessionId: widget.sessionId,
    subject: widget.subject,
    teacherName: SecureApiService().userName,
    code: _code,
    codeExpiresAt: DateTime.now().add(Duration(seconds: _secondsLeft)),
    lat: widget.lat,
    lng: widget.lng,
    radiusMeters: widget.radiusMeters,
  );

  void _onHotspotMark(AttendanceHotspotMark mark) {
    SyncQueueService.instance.enqueue('attendance_mark', {
      'sessionId': widget.sessionId,
      'studentId': mark.studentId,
      'clientMarkedAt': mark.clientMarkedAt.toUtc().toIso8601String(),
      'lat': mark.lat,
      'lng': mark.lng,
      'isMocked': mark.isMocked,
    });
    if (mounted) setState(() => _hotspotMarks += 1);
  }

  Future<void> _startHotspot() async {
    setState(() => _startingHotspot = true);
    try {
      final server = AttendanceHotspotServer();
      await server.start(_hotspotSession());
      _hotspot = server;
      _hotspotMarks = server.marks.length;
      _markSubs.add(server.onMark.listen(_onHotspotMark));
      await _discoverIps();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not start the hotspot server.');
    } finally {
      if (mounted) setState(() => _startingHotspot = false);
    }
  }

  Future<void> _startBle() async {
    setState(() => _startingBle = true);
    try {
      final host = AttendanceBleHost();
      await host.start(_hotspotSession());
      _bleHost = host;
      _hotspotMarks = host.marks.length;
      _markSubs.add(host.onSubmit.listen(_onHotspotMark));
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _startingBle = false);
    }
  }

  Future<void> _discoverIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final ips = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .where((a) => !a.startsWith('127.'))
          .toSet()
          .join(', ');
      if (mounted) setState(() => _localIps = ips.isEmpty ? null : ips);
    } catch (_) {
      _localIps = null;
    }
  }

  Future<void> _syncMarks() async {
    setState(() => _syncing = true);
    await SyncQueueService.instance.flush();
    if (!mounted) return;
    setState(() => _syncing = false);
    _loadRoster(silent: true);
  }

  Future<void> _tick() async {
    if (_secondsLeft > 1) {
      setState(() => _secondsLeft -= 1);
      return;
    }
    final result = await SecureApiService().getAttendanceCode(widget.sessionId);
    if (!mounted) return;
    if (result['code'] != null) {
      final newCode = result['code']?.toString() ?? '';
      if (newCode.isEmpty) return;
      final ttlRaw = result['codeTtlSeconds'];
      final newTtl = ttlRaw != null
          ? int.tryParse(ttlRaw.toString()) ?? 25
          : 25;
      setState(() {
        _code = newCode;
        _secondsLeft = newTtl;
      });
      // Keep the peer-to-peer session on the current code so students who
      // read it off the hotspot can mark directly to the server.
      _hotspot?.updateCode(
        _code,
        DateTime.now().add(Duration(seconds: _secondsLeft)),
      );
      final ble = _bleHost;
      if (ble != null && ble.isAdvertising) {
        ble.start(_hotspotSession());
      }
    } else if (result['codeTtlSeconds'] != null) {
      final ttlRaw = result['codeTtlSeconds'];
      final fallbackTtl = ttlRaw != null
          ? int.tryParse(ttlRaw.toString()) ?? 25
          : 25;
      setState(() => _secondsLeft = fallbackTtl);
    }
  }

  Future<void> _loadRoster({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingRoster = true);
    final result = await SecureApiService().getAttendanceRoster(
      widget.sessionId,
    );
    if (!mounted) return;
    if (result['roster'] != null) {
      setState(() {
        _roster = result['roster'] as List<dynamic>;
        _markedCount = result['markedCount'] as int? ?? 0;
        _totalStudents = result['totalStudents'] as int? ?? _roster.length;
        _isLoadingRoster = false;
      });
    } else {
      setState(() => _isLoadingRoster = false);
    }
  }

  Future<void> _override(String studentId, String status) async {
    final reason = await _askOverrideReason();
    if (reason == null || reason.isEmpty) return;
    await SecureApiService().overrideAttendance(
      widget.sessionId,
      studentId: studentId,
      status: status,
      reason: reason,
    );
    _loadRoster(silent: true);
  }

  Future<String?> _askOverrideReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reason for override'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Informed absent, on field trip',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Save',
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _closeSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close this session?'),
        content: const Text(
          'Students will no longer be able to mark themselves present after this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Close session',
            variant: NexusButtonVariant.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _closing = true);
    await _hotspot?.stop();
    await _bleHost?.stop();
    // Flush peer-to-peer marks before the server stops accepting them.
    await SyncQueueService.instance.flush();
    await SecureApiService().closeAttendanceSession(widget.sessionId);
    _tickTimer?.cancel();
    _rosterTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _closing = false;
      _closed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.sectionLabel} · ${widget.subject}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            if (_closed)
              NexusBanner(
                message: 'Session closed. No more attendance can be marked.',
                kind: NexusBannerKind.info,
              )
            else
              _buildCodeCard(t),
            const SizedBox(height: AppSpace.md),
            if (!_closed) _buildHotspotCard(t),
            const SizedBox(height: AppSpace.md),
            NexusCard(
              child: Row(
                children: [
                  Icon(Icons.groups_outlined, color: t.primary),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      '$_markedCount of $_totalStudents marked',
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (!_closed)
                    NexusButton(
                      label: 'Close session',
                      variant: NexusButtonVariant.secondary,
                      size: NexusButtonSize.small,
                      isLoading: _closing,
                      onPressed: _closing ? null : _closeSession,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (_isLoadingRoster)
              const NexusStateView.loading(rows: 4)
            else
              for (final raw in _roster)
                _buildRosterRow(Map<String, dynamic>.from(raw as Map)),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(AppTokens t) {
    return NexusCard(
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      child: Column(
        children: [
          Text('Show this code to your class', style: context.text.bodySmall),
          const SizedBox(height: AppSpace.sm),
          Text(
            _code,
            style: context.typeExtras.figureLg.copyWith(
              fontSize: 44,
              letterSpacing: 6,
              color: t.primary,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text('Refreshes in ${_secondsLeft}s', style: context.text.bodySmall),
        ],
      ),
    );
  }

  Widget _buildHotspotCard(AppTokens t) {
    final running =
        _hotspot?.isRunning == true || _bleHost?.isAdvertising == true;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                running ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                color: running ? t.statusPresent : t.inkFaint,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text('Offline hotspot', style: context.text.titleSmall),
              ),
              if (_hotspotMarks > 0)
                Text(
                  '$_hotspotMarks ${_hotspotMarks == 1 ? 'mark' : 'marks'}',
                  style: context.text.labelMedium?.copyWith(
                    color: t.statusPresent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            running
                ? _localIps != null
                      ? 'Students on this phone\'s hotspot can mark at http://$_localIps:8788. Marks queue here and sync when internet returns.'
                      : 'Students near this phone can mark over Bluetooth. Marks queue here and sync when internet returns.'
                : 'No internet in class? Students mark peer-to-peer (hotspot or Bluetooth) and marks sync to the server when you are back online.',
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
          if (running && _localIps != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              'http://$_localIps:8788',
              style: context.typeExtras.bodyStrong.copyWith(color: t.primary),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: NexusButton(
                  label: _hotspot?.isRunning == true
                      ? 'Stop hotspot'
                      : 'Start hotspot',
                  variant: NexusButtonVariant.secondary,
                  size: NexusButtonSize.small,
                  isLoading: _startingHotspot,
                  onPressed: () async {
                    if (_hotspot?.isRunning == true) {
                      await _hotspot?.stop();
                      if (mounted) setState(() {});
                    } else {
                      _startHotspot();
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: NexusButton(
                  label: _bleHost?.isAdvertising == true
                      ? 'Stop beacon'
                      : 'Start beacon',
                  variant: NexusButtonVariant.secondary,
                  size: NexusButtonSize.small,
                  isLoading: _startingBle,
                  onPressed: () async {
                    if (_bleHost?.isAdvertising == true) {
                      await _bleHost?.stop();
                      if (mounted) setState(() {});
                    } else {
                      _startBle();
                    }
                  },
                ),
              ),
            ],
          ),
          if (_hotspotMarks > 0) ...[
            const SizedBox(height: AppSpace.sm),
            NexusButton(
              label: 'Sync marks now',
              icon: Icons.cloud_upload_outlined,
              size: NexusButtonSize.small,
              fullWidth: true,
              isLoading: _syncing,
              onPressed: _syncing ? null : _syncMarks,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRosterRow(Map<String, dynamic> entry) {
    final status = entry['status'] as String?;
    final studentId = entry['studentId'] as String;
    final distance = (entry['distanceMeters'] as num?)?.toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: NexusCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['name'] as String? ?? '',
                    style: context.typeExtras.bodyStrong,
                  ),
                  if (status != null && distance != null)
                    Text(
                      'marked from ${distance}m',
                      style: context.text.bodySmall?.copyWith(
                        color: distance > 50
                            ? context.tokens.statusLate
                            : context.tokens.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
            if (status == null)
              Text('Not marked', style: context.text.bodySmall)
            else
              AttendanceStatusChip(status: _statusFrom(status), dense: true),
            if (!_closed)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) => _override(studentId, v),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'present', child: Text('Mark present')),
                  PopupMenuItem(value: 'late', child: Text('Mark late')),
                  PopupMenuItem(value: 'absent', child: Text('Mark absent')),
                  PopupMenuItem(value: 'leave', child: Text('Mark on leave')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  AttendanceStatus _statusFrom(String status) {
    switch (status) {
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'leave':
        return AttendanceStatus.leave;
      default:
        return AttendanceStatus.absent;
    }
  }
}
