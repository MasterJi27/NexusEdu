import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late List<Map<String, dynamic>> _notes;
  final List<Color> _noteColors = [
    Colors.amber.shade200,
    Colors.blue.shade200,
    Colors.green.shade200,
    Colors.pink.shade200,
    Colors.purple.shade200,
    Colors.teal.shade200,
    Colors.orange.shade200,
    Colors.red.shade200,
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    final cached = AppSettings.instance.cachedNotes;
    if (cached.isNotEmpty) {
      _notes = cached;
    } else {
      _notes = [
        {
          'title': 'AI & Machine Learning',
          'content': 'Key differences between Supervised and Unsupervised learning...\n- Supervised: Labeled data\n- Unsupervised: Unlabeled data',
          'color': Colors.amber.shade200,
          'date': 'Today',
          'subject': 'Computer Science',
        },
        {
          'title': 'Data Structures',
          'content': 'Trees vs Graphs. A tree is a special kind of graph with no cycles.',
          'color': Colors.blue.shade200,
          'date': 'Yesterday',
          'subject': 'Computer Science',
        },
        {
          'title': 'Project Ideas',
          'content': '1. AI Tutor\n2. Real-time Notes Scanner\n3. Flashcard Generator',
          'color': Colors.green.shade200,
          'date': '2 Days ago',
          'subject': 'General',
        },
        {
          'title': 'Physics Formulas',
          'content': 'F = ma\nE = mc^2\nv = u + at',
          'color': Colors.pink.shade200,
          'date': '1 Week ago',
          'subject': 'Physics',
        },
      ];
      _saveNotes();
    }
  }

  void _saveNotes() {
    AppSettings.instance.saveCachedNotes(_notes);
  }

  void _generateQuizFromNotes() async {
    final allContent = _notes.map((n) => n['title']).join(', ');
    if (allContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes to generate quiz from.')),
      );
      return;
    }
    final result = await AiService.generateSmartNotes(
      'Generate 5 MCQs with 4 options each and mark the correct answer, based on these topics: $allContent. Format as: Question? A) B) C) D) Answer: X',
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Quiz from Notes'),
        content: SingleChildScrollView(child: Text(result)),
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
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _exportNoteAsPdf(int index) {
    final note = _notes[index];
    final title = note['title'] ?? 'Untitled';
    final text = 'Title: $title\nSubject: ${note['subject'] ?? 'General'}\nDate: ${note['date'] ?? ''}\n\n${note['content'] ?? ''}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Note "$title" copied to clipboard')),
    );
  }

  void _deleteNote(int index) {
    final title = _notes[index]['title'] ?? 'Untitled';
    setState(() => _notes.removeAt(index));
    _saveNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "$title"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _notes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_add_outlined, size: 80, color: Colors.white.withAlpha(80)),
                    const SizedBox(height: 16),
                    Text('No notes yet', style: TextStyle(fontSize: 20, color: Colors.white.withAlpha(150))),
                    const SizedBox(height: 8),
                    Text('Tap + to create your first note', style: TextStyle(color: Colors.white.withAlpha(100))),
                  ],
                ),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return _buildNoteCard(note, index)
                      .animate()
                      .fade(delay: (100 * index).ms)
                      .scale();
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "scan",
            onPressed: () => context.push('/scanner'),
            child: const Icon(Icons.document_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "write",
            onPressed: () => context.push('/note-editor'),
            icon: const Icon(Icons.edit),
            label: const Text('Smart Note'),
          ),
        ],
      ).animate().slideY(begin: 1, end: 0, delay: 500.ms),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    final noteColor = note['color'] is Color ? note['color'] as Color : _noteColors[index % _noteColors.length];
    return GestureDetector(
      onLongPress: () => _showNoteOptions(index),
      child: Container(
        decoration: BoxDecoration(
          color: noteColor.withAlpha(40),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: noteColor.withAlpha(100), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: noteColor.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Expanded(
                    child: Text(
                      note['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'export', child: Text('Copy/Export')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (v) {
                      if (v == 'export') _exportNoteAsPdf(index);
                      if (v == 'delete') _deleteNote(index);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (note['subject'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: noteColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note['subject'],
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: noteColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white70),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note['content'] ?? 'No content',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(200),
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note['date'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy to Clipboard'),
              onTap: () {
                Navigator.pop(ctx);
                _exportNoteAsPdf(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: const Text('Generate Quiz from this Note'),
              onTap: () async {
                Navigator.pop(ctx);
                final note = _notes[index];
                final result = await AiService.generateSmartNotes(
                  'Generate 3 MCQs with 4 options each and mark the correct answer, based on: ${note["title"]} - ${note["content"]}',
                );
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text('Quiz: ${note["title"] ?? "Untitled"}'),
                    content: SingleChildScrollView(child: Text(result)),
                    actions: [
                      FilledButton(onPressed: () => Navigator.pop(dctx), child: const Text('OK')),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete Note', style: TextStyle(color: Colors.redAccent)),
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
