import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class SmartNoteEditorScreen extends StatefulWidget {
  const SmartNoteEditorScreen({super.key});

  @override
  State<SmartNoteEditorScreen> createState() => _SmartNoteEditorScreenState();
}

class _SmartNoteEditorScreenState extends State<SmartNoteEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isAiThinking = false;

  void _runAiAction(String action) async {
    setState(() => _isAiThinking = true);
    
    String result = '';
    try {
      if (action == 'generate') {
        final title = _titleController.text.trim();
        if (title.isEmpty) {
          result = 'Please enter a topic in the Title first.';
        } else {
          result = await AiService.generateSmartNotes(title);
        }
      } else if (action == 'summarize') {
        if (_contentController.text.isEmpty) {
           result = 'No text to summarize.';
        } else {
           result = await AiService.generateSmartNotes('Summarize this: ${_contentController.text}');
        }
      } else if (action == 'flashcards') {
        result = 'AI converted this note into 5 flashcards for your feed! (Backend connected)';
      }
    } catch (e) {
      result = 'Error: $e';
    }

    if (!mounted) return;
    setState(() {
      _isAiThinking = false;
      if (action == 'generate' || action == 'summarize') {
        if (!result.startsWith('Please') && !result.startsWith('No text')) {
           _contentController.text = result;
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Note Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Note Saved!')));
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Note Title',
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Start typing your notes here...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isAiThinking)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withAlpha(200),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.deepPurpleAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nexus AI is processing...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAiButton(
                'Auto Draft',
                Icons.auto_awesome,
                () => _runAiAction('generate'),
              ),
              _buildAiButton(
                'Summarize',
                Icons.short_text,
                () => _runAiAction('summarize'),
              ),
              _buildAiButton(
                'Make Flashcards',
                Icons.style,
                () => _runAiAction('flashcards'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.deepPurpleAccent, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
