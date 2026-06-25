import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class FlashcardDeckScreen extends StatefulWidget {
  const FlashcardDeckScreen({super.key});

  @override
  State<FlashcardDeckScreen> createState() => _FlashcardDeckScreenState();
}

class _FlashcardDeckScreenState extends State<FlashcardDeckScreen> {
  List<Map<String, dynamic>> get _decks => AppSettings.instance.flashcardDecks;

  void _refresh() => setState(() {});

  void _generateFromNotes() async {
    final notes = AppSettings.instance.cachedNotes;
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes available. Create some notes first.')),
      );
      return;
    }

    final selectedTopics = <String>[];
    final titles = notes.map((n) => n['title'] as String).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Notes for Flashcards'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: titles.length,
            itemBuilder: (c, i) => CheckboxListTile(
              title: Text(titles[i]),
              value: selectedTopics.contains(titles[i]),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    selectedTopics.add(titles[i]);
                  } else {
                    selectedTopics.remove(titles[i]);
                  }
                });
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: selectedTopics.isEmpty ? null : () {
              Navigator.pop(ctx);
              _generateWithTopic(selectedTopics.join(', '));
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _generateWithTopic(String topic) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await AiService.generateFlashcards(topic);
    if (!mounted) return;
    if (!context.mounted) return;
    Navigator.pop(context);

    List<dynamic> cards;
    try {
      cards = json.decode(result) as List<dynamic>;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse flashcards: $result')),
      );
      return;
    }

    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No flashcards generated.')),
      );
      return;
    }

    final cardList = cards
        .map((c) => {'front': c['front'] as String, 'back': c['back'] as String})
        .toList();

    final deck = {
      'name': topic.length > 30 ? '${topic.substring(0, 27)}...' : topic,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'cardCount': cardList.length,
      'cards': cardList,
    };

    await AppSettings.instance.addFlashcardDeck(deck);
    _refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deck "${deck['name']}" created with ${cardList.length} cards')),
    );
  }

  void _deleteDeck(int index) async {
    await AppSettings.instance.deleteFlashcardDeck(index);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDeckDialog(),
            tooltip: 'Create Deck',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _generateFromNotes,
            tooltip: 'Generate from Notes',
          ),
        ],
      ),
      body: _decks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style, size: 80, color: Colors.white.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('No flashcard decks yet',
                      style: TextStyle(fontSize: 20, color: Colors.white.withAlpha(150))),
                  const SizedBox(height: 8),
                  Text('Generate from notes or create a new deck',
                      style: TextStyle(color: Colors.white.withAlpha(100))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                return _buildDeckCard(deck, index, theme);
              },
            ),
    );
  }

  Widget _buildDeckCard(Map<String, dynamic> deck, int index, ThemeData theme) {
    final cardCount = deck['cardCount'] ?? (deck['cards'] as List?)?.length ?? 0;
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.style, color: Colors.deepPurpleAccent),
        ),
        title: Text(
          deck['name'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${deck['date'] ?? ''}  \u2022  $cardCount cards',
          style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'review', child: Text('Review')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (v) {
            if (v == 'review') {
              context.push('/flashcards/review', extra: {'deckIndex': index, 'deck': deck});
            } else if (v == 'delete') {
              _deleteDeck(index);
            }
          },
        ),
        onTap: () {
          context.push('/flashcards/review', extra: {'deckIndex': index, 'deck': deck});
        },
      ),
    );
  }

  void _showCreateDeckDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Flashcard Deck'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter a topic...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final topic = controller.text.trim();
              if (topic.isNotEmpty) {
                Navigator.pop(ctx);
                _generateWithTopic(topic);
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
