import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

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
        const SnackBar(
          content: Text('No notes available. Create some notes first.'),
        ),
      );
      return;
    }

    final selectedTopics = <String>[];
    final titles = notes
        .map((n) => n['title'] as String? ?? 'Untitled note')
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                  setDialogState(() {
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            NexusButton(
              label: 'Generate',
              onPressed: selectedTopics.isEmpty
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _generateWithTopic(selectedTopics.join(', '));
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _generateWithTopic(String topic) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String result;
    try {
      result = await AiService.generateFlashcards(topic);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't generate flashcards. Check your connection and try again."),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);

    List<dynamic> cards;
    try {
      cards = json.decode(result) as List<dynamic>;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't generate flashcards. Check your connection and try again."),
        ),
      );
      return;
    }

    if (cards.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No flashcards generated.')));
      return;
    }

    final cardList = cards
        .map(
          (c) => {'front': c['front'] as String, 'back': c['back'] as String},
        )
        .toList();

    final deck = {
      'name': topic.length > 30 ? '${topic.substring(0, 27)}...' : topic,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'cardCount': cardList.length,
      'cards': cardList,
    };

    await AppSettings.instance.addFlashcardDeck(deck);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deck "${deck['name']}" created with ${cardList.length} cards',
        ),
      ),
    );
  }

  void _deleteDeck(int index) async {
    await AppSettings.instance.deleteFlashcardDeck(index);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Flashcards',
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
      body: _decks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: NexusStateView.empty(
                  title: 'No flashcard decks yet',
                  description: 'Generate from notes or create a new deck',
                  icon: Icons.style,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpace.md),
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                return _buildDeckCard(deck, index);
              },
            ),
    );
  }

  Widget _buildDeckCard(Map<String, dynamic> deck, int index) {
    final t = context.tokens;
    final cardCount =
        deck['cardCount'] ?? (deck['cards'] as List?)?.length ?? 0;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.sm,
      ),
      onTap: () {
        context.push(
          '/flashcards/review',
          extra: {'deckIndex': index, 'deck': deck},
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Icons.style, color: t.primary),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck['name'] ?? 'Untitled',
                  style: context.text.titleSmall,
                ),
                Text(
                  '${deck['date'] ?? ''}  \u2022  $cardCount cards',
                  style: context.text.bodySmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'review', child: Text('Review')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (v) {
              if (v == 'review') {
                context.push(
                  '/flashcards/review',
                  extra: {'deckIndex': index, 'deck': deck},
                );
              } else if (v == 'delete') {
                _deleteDeck(index);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showCreateDeckDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Flashcard Deck'),
        content: NexusTextField(
          controller: controller,
          hint: 'Enter a topic...',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          NexusButton(
            label: 'Generate',
            onPressed: () {
              final topic = controller.text.trim();
              if (topic.isNotEmpty) {
                Navigator.pop(ctx);
                _generateWithTopic(topic);
              }
            },
          ),
        ],
      ),
    );
  }
}
