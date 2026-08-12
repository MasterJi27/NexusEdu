import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_stat_tile.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  bool _isTeacher = false;
  bool _switching = false;
  List<dynamic> _notes = [];

  /// Sample notes shown to guests so a teacher can see how the workspace
  /// looks before signing in. Every item is fictional and marked as demo —
  /// per PRODUCT.md, an on-screen fact must trace to the user's own data or
  /// be labelled.
  static final List<Map<String, dynamic>> _demoNotes = [
    {
      'demo': true,
      'gradeLevel': 'Class 11',
      'subject': 'Physics',
      'title': 'Laws of Motion — exam-ready points',
      'content':
          'Newton\u2019s three laws, when each applies, and the two most-asked numerical patterns from the last 5 years.',
    },
    {
      'demo': true,
      'gradeLevel': 'Class 10',
      'subject': 'Mathematics',
      'title': 'Quadratic equations: faster roots',
      'content':
          'The middle-term split worked through for 10 board-style problems, with the common sign mistakes called out.',
    },
    {
      'demo': true,
      'gradeLevel': 'Class 10',
      'subject': 'Chemistry',
      'title': 'Periodic table memory hooks',
      'content':
          'Group-wise mnemonics for the first 20 elements, valency table, and the trends that board papers actually test.',
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
        _isTeacher = false;
        _notes = _demoNotes;
      });
      return;
    }
    if (!api.isTeacher) {
      setState(() {
        _isTeacher = false;
        _isLoading = false;
      });
      return;
    }
    final notes = await api.getTeacherNotes();
    if (!mounted) return;
    setState(() {
      _isTeacher = true;
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _switchToTeacherMode() async {
    setState(() => _switching = true);
    final result = await SecureApiService().updateProfile(role: 'teacher');
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

  Future<void> _openCreateNoteSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String grade = LearningCatalog.classes.first;
    String subject = LearningCatalog.subjectsFor(grade).isNotEmpty
        ? LearningCatalog.subjectsFor(grade).first.name
        : 'General';

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final subjects = LearningCatalog.subjectsFor(
              grade,
            ).map((s) => s.name).toList();
            if (subjects.isNotEmpty && !subjects.contains(subject)) {
              subject = subjects.first;
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New note', style: context.text.headlineSmall),
                    const SizedBox(height: AppSpace.md),
                    NexusTextField(controller: titleController, label: 'Title'),
                    const SizedBox(height: AppSpace.sm),
                    NexusTextField(
                      controller: contentController,
                      label: 'Content',
                      maxLines: 6,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: grade,
                            decoration: const InputDecoration(
                              labelText: 'Grade',
                            ),
                            items: LearningCatalog.classes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setSheetState(() => grade = value ?? grade),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: subjects.contains(subject)
                                ? subject
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Subject',
                            ),
                            items: subjects
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setSheetState(() => subject = value ?? subject),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      child: NexusButton(
                        label: 'Publish to class',
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty ||
                              contentController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Title and content are required.',
                                ),
                              ),
                            );
                            return;
                          }
                          final result = await SecureApiService()
                              .createTeacherNote(
                                title: titleController.text.trim(),
                                content: contentController.text.trim(),
                                gradeLevel: grade,
                                subject: subject,
                              );
                          if (!sheetContext.mounted) return;
                          if (result['error'] != null) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'].toString()),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(sheetContext, true);
                        },
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();

    if (created == true) {
      _load();
    }
  }

  Future<void> _deleteNote(String id) async {
    final result = await SecureApiService().deleteTeacherNote(id);
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
      title: 'Teacher Dashboard',
      actions: [
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.person_outline),
          onPressed: () => context.push('/profile'),
        ),
        if (_isTeacher)
          IconButton(
            tooltip: 'Attendance',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => context.push('/attendance'),
          ),
      ],
      floatingActionButton: _isTeacher
          ? FloatingActionButton.extended(
              onPressed: _openCreateNoteSheet,
              icon: const Icon(Icons.add),
              label: const Text('New note'),
            )
          : null,
      body: _isLoading
          ? const NexusStateView.loading(rows: 4)
          : !SecureApiService().isLoggedIn
          ? _buildDemoExperience()
          : !_isTeacher
          ? _buildSwitchToTeacherPrompt()
          : _notes.isEmpty
          ? _buildEmptyState()
          : _buildNotesList(),
    );
  }

  /// Guest view: the same workspace shell with sample notes, every item
  /// clearly marked as demo, and one path into sign-in.
  Widget _buildDemoExperience() {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        NexusBanner(
          message:
              "You're seeing a demo. Sign in as a teacher to publish notes your students can see.",
          kind: NexusBannerKind.info,
          actionLabel: 'Sign in',
          onAction: () => context.go('/login'),
        ),
        const SizedBox(height: AppSpace.md),
        _buildOverviewCard(grades: 3, subjects: 3),
        const SizedBox(height: AppSpace.md),
        Text('Published notes', style: context.text.titleMedium),
        const SizedBox(height: AppSpace.xs),
        for (final rawNote in _notes)
          _buildNoteCard(Map<String, dynamic>.from(rawNote as Map), t),
        const SizedBox(height: AppSpace.md),
        NexusButton(
          label: 'Sign in to publish notes',
          icon: Icons.login,
          fullWidth: true,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  /// Strip markdown symbols for the 3-line preview so AI notes don't look
  /// like raw markup.
  static String _previewText(String md) => md.replaceAll(RegExp(r'[#*`_~]'), '');

  /// One note card. Real notes can be deleted; demo notes cannot.
  Widget _buildNoteCard(Map<String, dynamic> note, AppTokens t) {
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text(note['gradeLevel'] as String? ?? '')),
              const SizedBox(width: AppSpace.xs),
              Chip(label: Text(note['subject'] as String? ?? '')),
              if (note['demo'] == true) ...[
                const Spacer(),
                Icon(Icons.visibility_outlined, size: 18, color: t.inkMuted),
              ] else ...[
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: t.statusAbsent),
                  onPressed: () => _deleteNote(note['id'] as String),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            note['title'] as String? ?? '',
            style: context.text.titleMedium?.copyWith(color: t.ink),
          ),
          const SizedBox(height: 6),
          Text(
            _previewText(note['content'] as String? ?? ''),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchToTeacherPrompt() {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.co_present, color: t.secondary, size: 48),
            const SizedBox(height: AppSpace.md),
            Text(
              'Your account is registered as ${SecureApiService().role ?? 'student'}.',
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Switch to Teacher mode to publish notes that every student in a grade can see.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: AppSpace.lg),
            NexusButton(
              label: 'Switch to Teacher mode',
              icon: Icons.co_present,
              isLoading: _switching,
              onPressed: _switching ? null : _switchToTeacherMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: NexusStateView.empty(
          title: 'No notes yet',
          description:
              'Tap "New note" to publish your first one — every student in that grade sees it instantly.',
          icon: Icons.note_add_outlined,
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    final t = context.tokens;
    final grades = _notes
        .map((n) => (n as Map<String, dynamic>)['gradeLevel']?.toString())
        .whereType<String>()
        .toSet()
        .length;
    final subjects = _notes
        .map((n) => (n as Map<String, dynamic>)['subject']?.toString())
        .whereType<String>()
        .toSet()
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildOverviewCard(grades: grades, subjects: subjects),
        const SizedBox(height: AppSpace.md),
        Text('Published notes', style: context.text.titleMedium),
        const SizedBox(height: AppSpace.xs),
        for (final rawNote in _notes)
          Builder(
            builder: (context) =>
                _buildNoteCard(Map<String, dynamic>.from(rawNote as Map), t),
          ),
      ],
    );
  }

  Widget _buildOverviewCard({required int grades, required int subjects}) {
    final t = context.tokens;
    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      borderColor: t.primaryTintBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teaching workspace', style: context.text.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Publish reusable notes by grade and subject. Students see only the notes relevant to their class.',
            style: context.text.bodyMedium?.copyWith(
              color: t.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: NexusStatTile(
                  icon: Icons.note_alt_outlined,
                  iconColor: t.primary,
                  value: '${_notes.length}',
                  label: 'Notes',
                  bordered: false,
                  centered: true,
                ),
              ),
              Expanded(
                child: NexusStatTile(
                  icon: Icons.school_outlined,
                  iconColor: t.secondary,
                  value: '$grades',
                  label: 'Grades',
                  bordered: false,
                  centered: true,
                ),
              ),
              Expanded(
                child: NexusStatTile(
                  icon: Icons.menu_book_outlined,
                  iconColor: t.statusPresent,
                  value: '$subjects',
                  label: 'Subjects',
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
}
