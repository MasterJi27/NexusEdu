import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<Map<String, dynamic>> _notes = [
    {
      'title': 'AI & Machine Learning',
      'content':
          'Key differences between Supervised and Unsupervised learning...\n- Supervised: Labeled data\n- Unsupervised: Unlabeled data',
      'color': Colors.amber.shade200,
      'date': 'Today',
    },
    {
      'title': 'Data Structures',
      'content':
          'Trees vs Graphs. A tree is a special kind of graph with no cycles.',
      'color': Colors.blue.shade200,
      'date': 'Yesterday',
    },
    {
      'title': 'Project Ideas',
      'content':
          '1. AI Tutor\n2. Real-time Notes Scanner\n3. Flashcard Generator',
      'color': Colors.green.shade200,
      'date': '2 Days ago',
    },
    {
      'title': 'Physics Formulas',
      'content': 'F = ma\nE = mc^2\nv = u + at',
      'color': Colors.pink.shade200,
      'date': '1 Week ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Notes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: _notes.length,
          itemBuilder: (context, index) {
            final note = _notes[index];
            return _buildNoteCard(
              note,
            ).animate().fade(delay: (100 * index).ms).scale();
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "scan",
            onPressed: () {
              context.push('/scanner');
            },
            child: const Icon(Icons.document_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "write",
            onPressed: () {
              context.push('/note-editor');
            },
            icon: const Icon(Icons.edit),
            label: const Text('Smart Note'),
          ),
        ],
      ).animate().slideY(begin: 1, end: 0, delay: 500.ms),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    return Container(
      decoration: BoxDecoration(
        color: note['color']?.withAlpha(40) ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: note['color']?.withAlpha(100) ?? Colors.grey.withAlpha(50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: note['color']?.withAlpha(20) ?? Colors.black12,
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
            Text(
              note['title'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                note['content'],
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withAlpha(200),
                ),
                overflow: TextOverflow.fade,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              note['date'],
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
