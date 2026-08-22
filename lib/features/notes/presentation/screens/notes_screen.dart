import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/notes_sync_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/features/attendance/presentation/screens/qr_scanner_screen.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_list_row.dart';
import 'package:nexus_edu/shared/widgets/nexus_markdown.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/paginated_list.dart';
import 'package:nexus_edu/core/utils/pagination.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _notes = [];
  List<dynamic> _classNotes = [];
  bool _loadingClassNotes = true;
  // PaginatedList stub for 1M-scale class notes — backend will return {items, nextCursor, hasMore}
  String? _classNotesCursor;
  bool _classNotesHasMore = false;
  bool _classNotesLoadingMore = false;
  PaginatedList<dynamic> get _classNotesPaginated =>
      PaginatedList(items: _classNotes, nextCursor: _classNotesCursor, hasMore: _classNotesHasMore);

  /// Tint palette for note cards. Status colours are never spent on
  /// decoration — green means "present", not "saved" — so notes use the
  /// neutral tint set only.
  List<(Color, Color)> _notePalette(AppTokens t) => [
    (t.primaryTint, t.primaryTintBorder),
    (t.secondaryTint, t.borderStrong),
    (t.surfaceAlt, t.border),
    (t.primaryTintBorder, t.borderStrong),
    (t.borderStrong, t.border),
    (t.secondaryTint, t.borderStrong),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) setState(() {});
      });
    _loadNotes();
    _loadClassNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClassNotes() async {
    if (!SecureApiService().isLoggedIn) {
      if (!mounted) return;
      setState(() => _loadingClassNotes = false);
      return;
    }
    final notes = await SecureApiService().getTeacherNotes();
    if (!mounted) return;
    setState(() {
      _classNotes = notes;
      _loadingClassNotes = false;
      // TODO: when backend paginates teacher-notes, parse nextCursor/hasMore from Result
      _classNotesCursor = null;
      _classNotesHasMore = false;
    });
  }

  Future<void> _loadMoreClassNotes() async {
    if (_classNotesLoadingMore || !_classNotesHasMore) return;
    setState(() => _classNotesLoadingMore = true);
    try {
      // TODO: paginate with ?limit=20&cursor=_classNotesCursor when backend supports it
      // final result = await SecureApiService().getTeacherNotes(limit: 20, cursor: _classNotesCursor);
      // if (!mounted) return;
      // setState(() {
      //   _classNotes.addAll(result.items);
      //   _classNotesCursor = result.nextCursor;
      //   _classNotesHasMore = result.hasMore;
      // });
    } finally {
      if (mounted) setState(() => _classNotesLoadingMore = false);
    }
  }

  /// Demo notes are guest-only: once a student logs in, their notes come
  /// from the server and the placeholders never surface again.
  List<Map<String, dynamic>> _demoNotes() => [
    {
      'title': 'AI & Machine Learning',
      'content': 'Key differences between Supervised and Unsupervised learning...\n- Supervised: Labeled data\n- Unsupervised: Unlabeled data',
      'date': 'Today',
      'subject': 'Computer Science',
      'demo': true,
    },
    {
      'title': 'Data Structures',
      'content': 'Trees vs Graphs. A tree is a special kind of graph with no cycles.',
      'date': 'Yesterday',
      'subject': 'Computer Science',
      'demo': true,
    },
    {
      'title': 'Project Ideas',
      'content': '1. AI Tutor\n2. Real-time Notes Scanner\n3. Flashcard Generator',
      'date': '2 Days ago',
      'subject': 'General',
      'demo': true,
    },
    {
      'title': 'Physics Formulas',
      'content': 'F = ma\nE = mc^2\nv = u + at',
      'date': '1 Week ago',
      'subject': 'Physics',
      'demo': true,
    },
  ];

  /// Cache-first render, then a background pull from the server when logged
  /// in. Guest data (with any real notes) gets uploaded during the pull.
  Future<void> _loadNotes() async {
    final loggedIn = SecureApiService().isLoggedIn;
    var cached = AppSettings.instance.cachedNotes;
    if (cached.isEmpty && !loggedIn) {
      cached = _demoNotes();
      AppSettings.instance.saveCachedNotes(cached);
    }
    if (!mounted) return;
    setState(() => _notes = cached);
    if (!loggedIn) return;
    final merged = await NotesSyncService.pull(cached);
    if (!mounted) return;
    setState(() => _notes = merged);
    NotesSyncService.pushDirty(merged);
  }

  void _saveNotes() {
    final sanitized = _notes.map((n) {
      final c = n['color'];
      if (c is Color) return {...n, 'color': (c as Color).value};
      return n;
    }).toList();
    AppSettings.instance.saveCachedNotes(sanitized);
    // Keep in-memory list in sanitized form too to avoid re-persisting Color
    _notes = sanitized;
    NotesSyncService.pushDirty(sanitized);
  }

  void _generateQuizFromNotes() async {
    final allContent = _notes.map((n) => n['title']).join(', ');
    if (allContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes to generate quiz from.')),
      );
      return;
    }
    String result;
    try {
      result = await AiService.generateSmartNotes(
        'Generate 5 MCQs with 4 options each and mark the correct answer, based on these topics: $allContent. Format as: Question? A) B) C) D) Answer: X',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't generate a quiz. Check your connection and try again."),
        ),
      );
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Quiz from Notes'),
        content: SingleChildScrollView(child: NexusMarkdown(result, shrinkWrap: true)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quiz copied!')),
              );
            },
            child: const Text('Copy'),
          ),
          NexusButton(onPressed: () => Navigator.pop(ctx), label: 'OK'),
        ],
      ),
    );
  }

  Future<void> _exportNoteAsPdf(int index) async {
    final note = _notes[index];
    final title = note['title'] ?? 'Untitled';
    final bytes = await buildNotePdf(
      title: title,
      subject: note['subject'] ?? 'General',
      date: note['date'] ?? '',
      content: note['content'] ?? '',
    );
    if (!mounted) return;
    try {
      await Printing.sharePdf(bytes: bytes, filename: '${title.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  void _copyNote(int index) {
    final note = _notes[index];
    final title = note['title'] ?? 'Untitled';
    final text = 'Title: $title\nSubject: ${note['subject'] ?? 'General'}\nDate: ${note['date'] ?? ''}\n\n${note['content'] ?? ''}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note "$title" copied to clipboard')),
    );
  }

  void _deleteNote(int index) {
    final note = _notes[index];
    final title = note['title'] ?? 'Untitled';
    setState(() => _notes.removeAt(index));
    _saveNotes();
    NotesSyncService.deleteOnServer(note['id']?.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "$title"')),
    );
  }

  /// Opens an existing note for viewing/editing. Returns to a fresh grid so
  /// the updated title/content are reflected immediately.
  Future<void> _openNote(int index) async {
    final note = _notes[index];
    await context.push(
      '/note-editor',
      extra: {'index': index, ...note},
    );
    if (mounted) _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'My Notes'), Tab(text: 'Class Notes')],
        ),
        actions: _tabController.index == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.quiz_outlined),
                  onPressed: _generateQuizFromNotes,
                  tooltip: 'AI Quiz from Notes',
                ),
                IconButton(
                  icon: const Icon(Icons.style),
                  onPressed: () => context.push('/flashcards'),
                  tooltip: 'Flashcards',
                ),
              ]
            : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAiToolsStrip(),
                const SizedBox(height: AppSpace.sm),
                Expanded(
                  child: _notes.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpace.lg),
                            child: NexusStateView.empty(
                              title: 'No notes yet',
                              description:
                                  'Tap Smart Note to create your first note, or Auto Draft to let AI write one from a topic.',
                              icon: Icons.note_add_outlined,
                            ),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpace.md,
                            mainAxisSpacing: AppSpace.md,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            return _buildNoteCard(note, index);
                          },
                        ),
                ),
              ],
            ),
          ),
          _buildClassNotesTab(),
        ],
      ),
      floatingActionButton: _tabController.index != 0
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: "scan",
                  onPressed: () => context.push('/scanner'),
                  child: const Icon(Icons.document_scanner),
                ),
                const SizedBox(height: AppSpace.sm),
                FloatingActionButton.extended(
                  heroTag: "write",
                  onPressed: () => context.push('/note-editor'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Smart Note'),
                ),
              ],
            ),
    );
  }

  /// Always-visible AI actions for notes — no long-press hunting needed.
  Widget _buildAiToolsStrip() {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: _AiToolChip(
            icon: Icons.auto_awesome,
            label: 'Auto Draft',
            onTap: () => context.push('/note-editor'),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _AiToolChip(
            icon: Icons.quiz_outlined,
            label: 'Quiz',
            onTap: _generateQuizFromNotes,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _AiToolChip(
            icon: Icons.style_outlined,
            label: 'Flashcards',
            onTap: () => context.push('/flashcards'),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        IconButton(
          tooltip: 'Import a note from QR',
          onPressed: _importNoteFromQr,
          icon: Icon(Icons.qr_code_scanner, color: t.primary),
        ),
      ],
    );
  }

  /// Offline note sharing: the QR payload carries the note itself, so the
  /// receiver gets it with no internet, no account, no backend.
  String _notePayload(Map<String, dynamic> note) {
    final json = jsonEncode({
      't': note['title'] ?? 'Untitled',
      'c': note['content'] ?? '',
    });
    return 'nexusedu://note/${base64Url.encode(utf8.encode(json))}';
  }

  /// Decodes a scanned QR payload into a note, or returns null.
  Map<String, dynamic>? _decodeNotePayload(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'nexusedu' || uri.host != 'note') {
      return null;
    }
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(uri.pathSegments.first)),
      ) as Map<String, dynamic>;
      return {
        'title': json['t']?.toString() ?? 'Untitled',
        'content': json['c']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _importNoteFromQr() async {
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (!mounted || raw == null) return;
    final note = _decodeNotePayload(raw);
    if (note == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That QR is not a Nexus Edu note.')),
      );
      return;
    }
    await AppSettings.instance.addCachedNote({
      ...note,
      'date': 'Today',
      'subject': 'Shared',
    });
    _loadNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note "${note['title']}" imported.')),
    );
  }

  void _shareNoteAsQr(int index) {
    final note = _notes[index];
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.xs,
            AppSpace.lg,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share this note', style: ctx.text.headlineSmall),
              const SizedBox(height: AppSpace.xxs),
              Text(
                'Works fully offline — the note is inside the QR.',
                style: ctx.text.bodySmall?.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: AppSpace.md),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: AppRadius.brLg,
                  border: Border.all(color: t.border),
                ),
                child: QrImageView(
                  data: _notePayload(note),
                  size: 200,
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
              const SizedBox(height: AppSpace.md),
              Text(
                note['title'] ?? 'Untitled',
                style: ctx.text.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassNotesTab() {
    if (_loadingClassNotes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!SecureApiService().isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: NexusStateView.empty(
            title: 'Sign in to see notes shared by your teachers.',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }
    if (_classNotes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadClassNotes,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: NexusStateView.empty(
                title: 'No class notes yet.\nSet your grade in Profile so teachers can reach you.',
                icon: Icons.school_outlined,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadClassNotes,
      child: PaginatedListView<dynamic>(
        items: _classNotesPaginated.items,
        hasMore: _classNotesPaginated.hasMore,
        isLoading: _classNotesLoadingMore,
        onLoadMore: _loadMoreClassNotes,
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 100),
        itemBuilder: (context, item, index) {
          final note = item as Map<String, dynamic>;
          final teacher = note['teacher'] as Map<String, dynamic>?;
          return _buildClassNoteCard(note, teacher);
        },
      ),
    );
  }

  Widget _buildClassNoteCard(
    Map<String, dynamic> note,
    Map<String, dynamic>? teacher,
  ) {
    final t = context.tokens;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text(note['subject'] as String? ?? '')),
              if (note['topic'] != null) ...[
                const SizedBox(width: AppSpace.xs),
                Chip(label: Text(note['topic'] as String)),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            note['title'] as String? ?? '',
            style: context.text.titleSmall,
          ),
          const SizedBox(height: AppSpace.xs),
          NexusMarkdown(note['content'] as String? ?? '', shrinkWrap: true),
          if (teacher?['name'] != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              '— ${teacher!['name']}',
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

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    final t = context.tokens;
    final palette = _notePalette(t);
    final rawColor = note['color'];
    final (fill, border) = rawColor is Color
        ? (rawColor, t.primaryTintBorder)
        : rawColor is int
            ? (Color(rawColor), t.primaryTintBorder)
            : palette[index % palette.length];
    return GestureDetector(
      onTap: () => _openNote(index),
      onLongPress: () => _showNoteOptions(index),
      child: NexusCard(
        padding: const EdgeInsets.all(AppSpace.md),
        background: fill,
        borderColor: border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note['title'] ?? 'Untitled',
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Export PDF'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (v) {
                    if (v == 'export') _exportNoteAsPdf(index);
                    if (v == 'delete') _deleteNote(index);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            if (note['subject'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: AppSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: border),
                ),
                child: Text(
                  note['subject'],
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
            if (note['latitude'] != null && note['longitude'] != null) ...[
              const SizedBox(height: AppSpace.xxs),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 12, color: t.inkFaint),
                  const SizedBox(width: 2),
                  Text(
                    '${(note['latitude'] as num).toStringAsFixed(3)}, '
                    '${(note['longitude'] as num).toStringAsFixed(3)}',
                    style: context.text.labelSmall?.copyWith(
                      color: t.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.xs),
            Expanded(
              child: Text(
                note['content'] ?? 'No content',
                style: context.text.bodyMedium?.copyWith(
                  color: t.inkMuted,
                ),
                overflow: TextOverflow.fade,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              note['date'] ?? '',
              style: context.text.bodySmall?.copyWith(
                color: t.inkFaint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteOptions(int index) {    final t = context.tokens;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NexusListRow(
              leadingIcon: Icons.copy,
              title: 'Copy to Clipboard',
              onTap: () {
                Navigator.pop(ctx);
                _copyNote(index);
              },
            ),
            NexusListRow(
              leadingIcon: Icons.picture_as_pdf_outlined,
              title: 'Export as PDF',
              onTap: () {
                Navigator.pop(ctx);
                _exportNoteAsPdf(index);
              },
            ),
            NexusListRow(
              leadingIcon: Icons.quiz,
              iconColor: t.secondary,
              title: 'Generate Quiz from this Note',
              onTap: () async {
                Navigator.pop(ctx);
                final note = _notes[index];
                String result;
                try {
                  result = await AiService.generateSmartNotes(
                    'Generate 3 MCQs with 4 options each and mark the correct answer, based on: ${note["title"]} - ${note["content"]}',
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Couldn't generate a quiz. Check your connection and try again."),
                    ),
                  );
                  return;
                }
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text('Quiz: ${note["title"] ?? "Untitled"}'),
                    content: SingleChildScrollView(
                      child: NexusMarkdown(result, shrinkWrap: true),
                    ),
                    actions: [
                      NexusButton(
                        onPressed: () => Navigator.pop(dctx),
                        label: 'OK',
                      ),
                    ],
                  ),
                );
              },
            ),
            NexusListRow(
              leadingIcon: Icons.qr_code_2,
              title: 'Share via QR (offline)',
              onTap: () {
                Navigator.pop(ctx);
                _shareNoteAsQr(index);
              },
            ),
            const Divider(height: 1),
            NexusListRow(
              leadingIcon: Icons.delete_outline,
              iconColor: t.statusAbsent,
              titleColor: t.statusAbsent,
              title: 'Delete Note',
              onTap: () {
                Navigator.pop(ctx);
                _deleteNote(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill button for the always-visible AI notes actions.
class _AiToolChip extends StatelessWidget {
  const _AiToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.primaryTint,
      borderRadius: AppRadius.brLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: t.primary),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: t.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Markdown → plain text for the PDF writer (it has no markdown renderer).
/// Keeps list bullets and paragraph breaks so the PDF stays readable.
String stripMarkdownForPdf(String md) => md
    .replaceAll(RegExp(r'[#*`_~]'), '')
    .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '• ')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Builds a shareable PDF document from a note's fields.
Future<Uint8List> buildNotePdf({
  required String title,
  required String subject,
  required String date,
  required String content,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Subject: $subject   Date: $date',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          for (final block
              in stripMarkdownForPdf(content).split(RegExp(r'\n\s*\n')))
            if (block.trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  block.trim(),
                  style: const pw.TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
        ],
      ),
    ),
  );
  return doc.save();
}
