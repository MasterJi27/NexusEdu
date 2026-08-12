import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/location_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_list_row.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Deep-link-ish payload inside a classroom QR. Students scan it from the
/// Mark Attendance screen; the code alone is also valid to type in.
String sectionInvitePayload(String inviteCode) =>
    'nexusedu://section/$inviteCode';

/// Extracts the classroom invite code from a scanned payload, or returns the
/// raw input when it is already a bare code.
String? inviteCodeFromPayload(String raw) {
  final trimmed = raw.trim().toUpperCase();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme == 'nexusedu' && uri.host == 'section') {
    final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return code.length == 6 ? code : null;
  }
  if (RegExp(r'^[A-Z2-9]{6}$').hasMatch(trimmed)) return trimmed;
  return null;
}

/// Teacher's own class rosters. A Section is deliberately teacher-owned with
/// no separate School/tenant model yet — see backend/prisma/schema.prisma for
/// why building that now would be designing ahead of a need no real pilot
/// has asked for yet.
class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (!SecureApiService().isLoggedIn || !SecureApiService().isTeacher) {
      setState(() => _isLoading = false);
      return;
    }
    final sections = await SecureApiService().getSections();
    if (!mounted) return;
    setState(() {
      _sections = sections;
      _isLoading = false;
    });
  }

  Future<void> _createSection() async {
    final labelController = TextEditingController();
    String grade = LearningCatalog.classes.first;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('New section'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NexusTextField(
                controller: labelController,
                label: 'Section name',
                hint: 'e.g. Class 10-B',
              ),
              const SizedBox(height: AppSpace.sm),
              Text('Grade', style: dialogContext.text.labelMedium),
              const SizedBox(height: AppSpace.xs),
              DropdownButton<String>(
                value: grade,
                isExpanded: true,
                items: LearningCatalog.classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => grade = v ?? grade),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  error!,
                  style: dialogContext.text.bodySmall?.copyWith(
                    color: dialogContext.tokens.statusAbsent,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            NexusButton(
              label: 'Create',
              onPressed: () async {
                final label = labelController.text.trim();
                if (label.isEmpty) return;
                final result = await SecureApiService().createSection(
                  label: label,
                  gradeLevel: grade,
                );
                if (!dialogContext.mounted) return;
                if (result['error'] != null) {
                  setDialogState(() => error = result['error'].toString());
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
    if (created == true) _load();
  }

  Future<void> _openRoster(Map<String, dynamic> section) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RosterSheet(
        sectionId: section['id'] as String,
        sectionLabel: section['label'] as String,
      ),
    );
    _load();
  }

  Future<void> _startSession(Map<String, dynamic> section) async {
    final subjectController = TextEditingController(
      text: section['subject']?.toString() ?? '',
    );
    final subject = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start attendance'),
        content: NexusTextField(
          controller: subjectController,
          label: 'Subject',
          hint: 'e.g. Physics',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Start',
            onPressed: () =>
                Navigator.pop(dialogContext, subjectController.text.trim()),
          ),
        ],
      ),
    );
    subjectController.dispose();
    if (subject == null || subject.isEmpty || !mounted) return;

    final fence = await _askGeoFence();
    if (fence == null || !mounted) return;

    // Teacher declined location: run without a fence (server accepts marks
    // from anywhere, like pre-fence sessions).
    final result = await SecureApiService().startAttendanceSession(
      section['id'] as String,
      subject,
      lat: fence['noFence'] == true ? null : (fence['lat'] as double),
      lng: fence['noFence'] == true ? null : (fence['lng'] as double),
      radiusMeters: fence['noFence'] == true ? 75 : (fence['radius'] as int),
    );
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['error'].toString())));
      return;
    }
    context.push(
      '/attendance/session',
      extra: {
        'sessionId': result['id'] as String,
        'sectionLabel': section['label'] as String,
        'subject': subject,
        'code': result['code'] as String,
        'codeTtlSeconds': result['codeTtlSeconds'] as int,
        if (fence['noFence'] != true) 'lat': fence['lat'] as double,
        if (fence['noFence'] != true) 'lng': fence['lng'] as double,
        if (fence['noFence'] != true) 'radiusMeters': fence['radius'] as int,
      },
    );
  }

  /// Pins the session to the classroom: reads the teacher's current position
  /// (with a permission prompt) and lets them tune the radius. Declining
  /// location is allowed — the session just runs without a fence.
  Future<Map<String, dynamic>?> _askGeoFence() async {
    var position = await LocationService.getCurrentPosition();
    if (!mounted) return null;
    var radius = 75.0;
    var error = position == null
        ? 'Location is unavailable — students will be able to mark from anywhere.'
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Pin students to this classroom?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Students will only be able to mark attendance within the radius below. This stops codes from being forwarded outside the room.',
                style: dialogContext.text.bodySmall,
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Icon(
                    position != null
                        ? Icons.location_on_outlined
                        : Icons.location_off_outlined,
                    color: position != null
                        ? dialogContext.tokens.statusPresent
                        : dialogContext.tokens.statusAbsent,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      position != null
                          ? 'Classroom pinned at your current location.'
                          : error!,
                      style: dialogContext.text.bodySmall,
                    ),
                  ),
                ],
              ),
              if (position != null) ...[
                const SizedBox(height: AppSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Radius', style: dialogContext.text.labelMedium),
                    Text(
                      '${radius.round()} m',
                      style: dialogContext.text.labelMedium?.copyWith(
                        color: dialogContext.tokens.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: radius,
                  min: 25,
                  max: 300,
                  divisions: 11,
                  label: '${radius.round()} m',
                  onChanged: (v) => setDialogState(() => radius = v),
                ),
                Text(
                  'A lecture hall is usually 75–150 m.',
                  style: dialogContext.text.bodySmall,
                ),
              ],
              if (position == null) ...[
                const SizedBox(height: AppSpace.md),
                TextButton.icon(
                  onPressed: () async {
                    setDialogState(() => error = 'Reading location…');
                    final pos = await LocationService.getCurrentPosition();
                    if (!dialogContext.mounted) return;
                    setDialogState(() {
                      position = pos;
                      error = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try location again'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Skip location'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            NexusButton(
              label: 'Start session',
              onPressed: position == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return null;
    final pinned = position;
    if (pinned == null) return const {'noFence': true};
    return {'lat': pinned.lat, 'lng': pinned.lng, 'radius': radius.round()};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      floatingActionButton: SecureApiService().isTeacher
          ? FloatingActionButton.extended(
              onPressed: _createSection,
              icon: const Icon(Icons.add),
              label: const Text('New section'),
            )
          : null,
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: NexusStateView.loading(rows: 3),
            )
          : !SecureApiService().isLoggedIn || !SecureApiService().isTeacher
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: NexusStateView.empty(
                  title: 'Teacher mode required',
                  description:
                      'Switch to Teacher mode from the Teacher Dashboard to take attendance.',
                  icon: Icons.co_present_outlined,
                ),
              ),
            )
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: NexusStateView.error(message: _error!, onRetry: _load),
            )
          : _sections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: NexusStateView.empty(
                  title: 'No sections yet',
                  description:
                      'Create a section for your class, add students by email, then start taking attendance.',
                  icon: Icons.groups_outlined,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.xxl,
                ),
                children: [
                  for (final raw in _sections)
                    _buildSectionCard(Map<String, dynamic>.from(raw as Map)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final t = context.tokens;
    final count = ((section['_count'] as Map?)?['enrollments'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: NexusCard(
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
                        section['label'] as String? ?? '',
                        style: context.text.titleMedium,
                      ),
                      Text(
                        '${section['gradeLevel']} · $count student${count == 1 ? '' : 's'}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Manage roster',
                  onPressed: () => _openRoster(section),
                  icon: Icon(Icons.group_outlined, color: t.inkMuted),
                ),
                IconButton(
                  tooltip: 'Share classroom QR',
                  onPressed: () => _shareSection(section),
                  icon: Icon(Icons.qr_code_2, color: t.inkMuted),
                ),
                IconButton(
                  tooltip: 'Post syllabus (AI notes)',
                  onPressed: () => _postSyllabus(section),
                  icon: Icon(Icons.menu_book_outlined, color: t.inkMuted),
                ),
                IconButton(
                  tooltip: 'Class tasks',
                  onPressed: () => _openTasks(section),
                  icon: Icon(Icons.task_alt, color: t.inkMuted),
                ),
                IconButton(
                  tooltip: 'Offline exams',
                  onPressed: () => context.push('/offline-exam'),
                  icon: Icon(Icons.wifi_tethering_outlined, color: t.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            NexusButton(
              label: 'Take attendance',
              icon: Icons.qr_code_2_outlined,
              fullWidth: true,
              onPressed: count == 0 ? null : () => _startSession(section),
            ),
            if (count == 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxs),
                child: Text(
                  'Add students to this section first.',
                  style: context.text.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _shareSection(Map<String, dynamic> section) {
    final inviteCode = (section['inviteCode'] as String?)?.trim();
    if (inviteCode == null || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This section has no invite code yet.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShareSectionSheet(
        sectionLabel: section['label'] as String? ?? 'Classroom',
        inviteCode: inviteCode,
      ),
    );
  }

  /// Google-Classroom-style syllabus: teacher pastes the syllabus document
  /// and the AI converts it into structured study notes for the section
  /// (published + RAG-indexed), notifying every enrolled student.
  Future<void> _postSyllabus(Map<String, dynamic> section) async {
    final titleController = TextEditingController(
      text: '${section['label']} Syllabus',
    );
    final syllabusController = TextEditingController();
    bool posting = false;
    String? error;

    final posted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Post syllabus'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste your syllabus document. AI converts it into chapter-by-chapter notes for students (published + searchable).',
                  style: dialogContext.text.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: titleController,
                  label: 'Title',
                ),
                const SizedBox(height: AppSpace.sm),
                SizedBox(
                  height: 180,
                  child: NexusTextField(
                    controller: syllabusController,
                    label: 'Syllabus',
                    hint: 'Chapter 1: ...\nChapter 2: ...',
                    maxLines: 8,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    error!,
                    style: dialogContext.text.bodySmall?.copyWith(
                      color: dialogContext.tokens.statusAbsent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            NexusButton(
              label: posting ? 'Converting…' : 'Post & generate notes',
              isLoading: posting,
              onPressed: posting
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final syllabus = syllabusController.text.trim();
                      if (title.isEmpty || syllabus.length < 10) {
                        setDialogState(
                          () => error =
                              'Add a title and at least a few lines of syllabus.',
                        );
                        return;
                      }
                      setDialogState(() {
                        posting = true;
                        error = null;
                      });
                      final result = await SecureApiService().postSyllabus(
                        sectionId: section['id'] as String,
                        title: title,
                        syllabus: syllabus,
                      );
                      if (!dialogContext.mounted) return;
                      if (result['error'] != null) {
                        setDialogState(() {
                          posting = false;
                          error = result['error'].toString();
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    syllabusController.dispose();
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Syllabus notes generated. Students were notified.',
          ),
        ),
      );
    }
  }

  /// Task stream for one section: create, toggle visibility of submissions,
  /// delete. Students see the same stream in their Classroom tab.
  Future<void> _openTasks(Map<String, dynamic> section) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TasksSheet(
        sectionId: section['id'] as String,
        sectionLabel: section['label'] as String,
      ),
    );
  }
}

/// Bottom sheet showing the classroom QR + invite code so students can join
/// the section from the Mark Attendance screen.
class _ShareSectionSheet extends StatelessWidget {
  const _ShareSectionSheet({
    required this.sectionLabel,
    required this.inviteCode,
  });

  final String sectionLabel;
  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Join $sectionLabel', style: context.text.headlineSmall),
            const SizedBox(height: AppSpace.xxs),
            Text(
              'Students scan this QR (or type the code) in Mark Attendance to join your classroom.',
              style: context.text.bodySmall?.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: AppSpace.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: AppRadius.brLg,
                  border: Border.all(color: t.border),
                ),
                child: QrImageView(
                  data: sectionInvitePayload(inviteCode),
                  size: 220,
                  backgroundColor: t.surface,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: t.ink,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: t.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Center(
              child: Text(
                inviteCode,
                style: context.typeExtras.figureLg.copyWith(
                  color: t.ink,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            NexusButton(
              label: 'Copy invite code',
              icon: Icons.copy_outlined,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterSheet extends StatefulWidget {
  const _RosterSheet({required this.sectionId, required this.sectionLabel});

  final String sectionId;
  final String sectionLabel;

  @override
  State<_RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends State<_RosterSheet> {
  bool _isLoading = true;
  List<dynamic> _roster = [];
  final _emailController = TextEditingController();
  bool _adding = false;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final roster = await SecureApiService().getSectionRoster(widget.sectionId);
    if (!mounted) return;
    setState(() {
      _roster = roster;
      _isLoading = false;
    });
  }

  Future<void> _addStudent() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _adding = true;
      _addError = null;
    });
    final result = await SecureApiService().addStudentToSection(
      widget.sectionId,
      email,
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (result['error'] != null) {
      setState(() => _addError = result['error'].toString());
      return;
    }
    _emailController.clear();
    _load();
  }

  Future<void> _removeStudent(String studentId) async {
    await SecureApiService().removeStudentFromSection(
      widget.sectionId,
      studentId,
    );
    _load();
  }

  Future<void> _importCsv() async {
    final csvController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import roster'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste one student per line: email,rollNumber',
              style: dialogContext.text.bodySmall,
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 180,
              child: NexusTextField(
                controller: csvController,
                label: 'CSV',
                hint: 'student@example.com,1\nstudent2@example.com,2',
                maxLines: 6,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Students without an account yet are skipped and reported.',
              style: dialogContext.text.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Import',
            onPressed: () =>
                Navigator.pop(dialogContext, {'csv': csvController.text}),
          ),
        ],
      ),
    );
    csvController.dispose();
    if (result == null || !mounted) return;
    final csv = (result['csv'] as String?)?.trim() ?? '';
    if (csv.isEmpty) return;

    final outcome = await SecureApiService().importSectionCsv(
      widget.sectionId,
      csv,
    );
    if (!mounted) return;
    if (outcome['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(outcome['error'].toString())));
      return;
    }
    final missing = (outcome['missingStudents'] as List?) ?? const <dynamic>[];
    final message = missing.isEmpty
        ? 'Imported ${outcome['imported']} student(s).'
        : 'Imported ${outcome['imported']} student(s). '
              '${missing.length} not found: ${missing.join(', ')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
          Text(widget.sectionLabel, style: context.text.titleMedium),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: NexusTextField(
                  controller: _emailController,
                  label: 'Add student by email',
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _addStudent(),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: NexusButton(
                  label: 'Add',
                  size: NexusButtonSize.small,
                  isLoading: _adding,
                  onPressed: _adding ? null : _addStudent,
                ),
              ),
            ],
          ),
          if (_addError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                _addError!,
                style: context.text.bodySmall?.copyWith(
                  color: context.tokens.statusAbsent,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Import roster from CSV'),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          NexusSectionHeader(title: 'Roster', spaceAbove: 0),
          if (_isLoading)
            const NexusStateView.loading(rows: 3)
          else if (_roster.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Text(
                'No students added yet.',
                style: context.text.bodySmall,
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _roster.length,
                itemBuilder: (ctx, i) {
                  final e = Map<String, dynamic>.from(_roster[i] as Map);
                  final student = Map<String, dynamic>.from(
                    e['student'] as Map,
                  );
                  return NexusListRow(
                    leadingIcon: Icons.person_outline,
                    title: student['name'] as String? ?? '',
                    subtitle: student['email'] as String? ?? '',
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: context.tokens.statusAbsent,
                      ),
                      onPressed: () => _removeStudent(student['id'] as String),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Teacher-side task stream for a section: see everything, create, delete.
class _TasksSheet extends StatefulWidget {
  const _TasksSheet({required this.sectionId, required this.sectionLabel});

  final String sectionId;
  final String sectionLabel;

  @override
  State<_TasksSheet> createState() => _TasksSheetState();
}

class _TasksSheetState extends State<_TasksSheet> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await SecureApiService().getClassroomTasks(
      sectionId: widget.sectionId,
    );
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _createTask() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final pointsController = TextEditingController(text: '10');
    DateTime? dueDate;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('New task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NexusTextField(
                controller: titleController,
                label: 'Task title',
                hint: 'e.g. Solve 10 physics problems from Ch. 3',
                autofocus: true,
              ),
              const SizedBox(height: AppSpace.sm),
              NexusTextField(
                controller: descController,
                label: 'Details (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: NexusTextField(
                      controller: pointsController,
                      label: 'Points',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate ?? DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        dueDate == null
                            ? 'Due date'
                            : '${dueDate!.day}/${dueDate!.month}',
                      ),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  error!,
                  style: dialogContext.text.bodySmall?.copyWith(
                    color: dialogContext.tokens.statusAbsent,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            NexusButton(
              label: 'Assign',
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  setDialogState(() => error = 'Add a task title.');
                  return;
                }
                final result = await SecureApiService().createClassTask(
                  sectionId: widget.sectionId,
                  title: title,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  dueDate: dueDate,
                  points: int.tryParse(pointsController.text.trim()) ?? 10,
                );
                if (!dialogContext.mounted) return;
                if (result['error'] != null) {
                  setDialogState(() => error = result['error'].toString());
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descController.dispose();
    pointsController.dispose();
    if (created == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned. Students were notified.')),
        );
      }
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    await SecureApiService().deleteClassTask(task['id'] as String);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.lg,
        right: AppSpace.lg,
        top: AppSpace.sm,
        bottom: AppSpace.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tasks · ${widget.sectionLabel}',
                  style: context.text.titleMedium,
                ),
              ),
              NexusButton(
                label: 'Assign',
                icon: Icons.add,
                size: NexusButtonSize.small,
                onPressed: _createTask,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (_isLoading)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              child: Text(
                'No tasks yet. Assign the first one — students see it instantly and get a notification.',
                style: context.text.bodySmall?.copyWith(color: t.inkMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tasks.length,
                itemBuilder: (ctx, i) {
                  final task = Map<String, dynamic>.from(_tasks[i] as Map);
                  final done = (task['doneCount'] as int?) ?? 0;
                  final total = (task['submissionCount'] as int?) ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.task_alt,
                      color: done > 0 ? t.statusPresent : t.inkFaint,
                    ),
                    title: Text(task['title'] as String? ?? ''),
                    subtitle: Text(
                      total == 0
                          ? 'No submissions yet'
                          : '$done of $total students done',
                      style: context.text.bodySmall?.copyWith(
                        color: t.inkMuted,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: t.statusAbsent,
                      ),
                      onPressed: () => _deleteTask(task),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
