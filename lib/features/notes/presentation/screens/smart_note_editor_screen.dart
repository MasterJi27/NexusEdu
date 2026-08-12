import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/location_service.dart';
import 'package:nexus_edu/core/services/notes_sync_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

class SmartNoteEditorScreen extends StatefulWidget {
  const SmartNoteEditorScreen({super.key, this.initialNote});

  /// The note being edited, when opened from an existing note card.
  /// Carries `index` (position in the cached list) plus `title`/`content`/
  /// `subject` to prefill. Null means a brand-new note.
  final Map<String, dynamic>? initialNote;

  @override
  State<SmartNoteEditorScreen> createState() => _SmartNoteEditorScreenState();
}

class _SmartNoteEditorScreenState extends State<SmartNoteEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isAiThinking = false;
  int? get _editIndex => widget.initialNote?['index'] as int?;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialNote;
    if (initial != null) {
      _titleController.text = initial['title']?.toString() ?? '';
      _contentController.text = initial['content']?.toString() ?? '';
    }
  }

  void _saveNote() {
    final notes = AppSettings.instance.cachedNotes;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final index = _editIndex;
    final isEditing = index != null && index >= 0 && index < notes.length;

    final Map<String, dynamic> note;
    if (isEditing) {
      final existing = Map<String, dynamic>.from(notes[index]);
      note = {
        ...existing,
        'title': title.isEmpty ? 'Untitled' : title,
        'content': content.isEmpty ? 'No content' : content,
        'dirty': true,
      };
      notes[index] = note;
    } else {
      note = {
        'title': title.isEmpty ? 'Untitled' : title,
        'content': content.isEmpty ? 'No content' : content,
        'date': 'Today',
        'subject': widget.initialNote?['subject']?.toString() ?? 'General',
      };
      notes.insert(0, note);
    }
    AppSettings.instance.saveCachedNotes(notes);
    NotesSyncService.pushDirty(notes);
    // Best-effort geo-tag: a fix inside the 10s budget is attached (a note
    // taken at a field trip earns its location); denial/timeout/sensors-off
    // just leaves the note untagged. Never blocks the save.
    LocationService.getCurrentPosition().then((fix) {
      if (fix == null || !mounted) return;
      note['latitude'] = fix.lat;
      note['longitude'] = fix.lng;
      AppSettings.instance.saveCachedNotes(notes);
      NotesSyncService.pushDirty(notes);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(isEditing ? 'Note updated.' : 'Note saved.')));
    Navigator.pop(context, true);
  }

  void _runAiAction(String action) async {
    if (action == 'generate' && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic in the Title first.')),
      );
      return;
    }
    if (action == 'summarize' && _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to summarize.')),
      );
      return;
    }

    setState(() => _isAiThinking = true);

    try {
      if (action == 'generate') {
        final result = await AiService.generateSmartNotes(_titleController.text.trim());
        if (!mounted) return;
        setState(() => _contentController.text = result);
      } else if (action == 'summarize') {
        final result = await AiService.generateSmartNotes(
          'Summarize this: ${_contentController.text}',
        );
        if (!mounted) return;
        setState(() => _contentController.text = result);
      } else if (action == 'flashcards') {
        // Reuses the same generate-and-save path flashcard_deck_screen.dart
        // uses, instead of a canned "(Backend connected)" success message
        // with no backend call behind it.
        final title = _titleController.text.trim();
        final topic = title.isNotEmpty ? title : _contentController.text.trim();
        if (topic.isEmpty) {
          if (!mounted) return;
          setState(() => _isAiThinking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a title or some content first.')),
          );
          return;
        }
        final result = await AiService.generateFlashcards(topic);
        final cards = (json.decode(result) as List<dynamic>)
            .map((c) => {'front': c['front'] as String, 'back': c['back'] as String})
            .toList();
        final deck = {
          'name': topic.length > 30 ? '${topic.substring(0, 27)}...' : topic,
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'cardCount': cards.length,
          'cards': cards,
        };
        await AppSettings.instance.addFlashcardDeck(deck);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created "${deck['name']}" with ${cards.length} flashcards.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't reach the AI. Check your connection and try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAiThinking = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editIndex != null ? 'Edit note' : 'AI Note Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save note',
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: context.text.headlineMedium,
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
                    style: context.text.bodyLarge?.copyWith(height: 1.5),
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
              color: t.page.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      'Nexus AI is processing...',
                      style: context.text.bodyMedium?.copyWith(
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            boxShadow: AppElevation.e1(t.shadow),
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
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: t.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: t.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
