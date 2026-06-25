import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlashcardAutoGenScreen extends StatefulWidget {
  const FlashcardAutoGenScreen({super.key});

  @override
  State<FlashcardAutoGenScreen> createState() => _FlashcardAutoGenScreenState();
}

class _FlashcardAutoGenScreenState extends State<FlashcardAutoGenScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, String>> _flashcards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<Map<String, dynamic>> _savedSets = [];
  List<Map<String, String>> _keptCards = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('auto_flashcards') ?? [];
    setState(() {
      _savedSets = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateFlashcards() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _flashcards = [];
      _currentIndex = 0;
      _showAnswer = false;
      _keptCards = [];
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Generate 10 flashcards from the following content. '
              'Return ONLY a JSON array where each item has "question" and "answer" keys. '
              'Format: [{"question":"...","answer":"..."},...]\n\n'
              'Content:\n${_contentController.text.trim()}',
    });

    if (!mounted) return;

    try {
      final cleaned = result.replaceAll(RegExp(r'```json\n?|\n?```'), '').trim();
      final List<dynamic> parsed = json.decode(cleaned);
      final cards = parsed
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      setState(() {
        _isLoading = false;
        _flashcards = cards;
      });

      _savedSets.insert(0, {
        'content': _contentController.text.trim(),
        'count': cards.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (_savedSets.length > 50) _savedSets.removeLast();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'auto_flashcards',
        _savedSets.map((e) => json.encode(e)).toList(),
      );
    } catch (_) {
      setState(() {
        _isLoading = false;
        _flashcards = [
          {'question': 'Based on the content', 'answer': result},
        ];
      });
    }
  }

  void _keepCard() {
    if (_currentIndex < _flashcards.length) {
      _keptCards.add(_flashcards[_currentIndex]);
    }
    _nextCard();
  }

  void _discardCard() {
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      setState(() {
        _currentIndex = _flashcards.length;
        _showAnswer = false;
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Auto Flashcard Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste content to generate flashcards',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Paste study material, notes, or pick a file...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateFlashcards,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(200),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Generating Flashcards...' : 'Generate Flashcards',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 30),
              const Center(
                child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
              ),
            ],
            if (_flashcards.isNotEmpty && _currentIndex < _flashcards.length) ...[
              const SizedBox(height: 20),
              _buildProgressIndicator(),
              const SizedBox(height: 12),
              _buildFlashcardStack(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
            if (_flashcards.isNotEmpty && _currentIndex >= _flashcards.length) ...[
              const SizedBox(height: 20),
              _buildCompletionCard(),
            ],
            if (_savedSets.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Flashcard Sets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedSets.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedSets[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _flashcards.length,
            backgroundColor: Colors.white.withAlpha(15),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_currentIndex + 1}/${_flashcards.length}',
          style: const TextStyle(
            color: Colors.deepPurpleAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcardStack() {
    final card = _flashcards[_currentIndex];
    return GestureDetector(
      onTap: () => setState(() => _showAnswer = !_showAnswer),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Container(
          key: ValueKey('$_currentIndex-$_showAnswer'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 250),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.deepPurpleAccent.withAlpha(_showAnswer ? 60 : 30),
              width: _showAnswer ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withAlpha(_showAnswer ? 40 : 20),
                blurRadius: 20,
                spreadRadius: _showAnswer ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _showAnswer ? 'Answer' : 'Question',
                  style: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _showAnswer ? (card['answer'] ?? '') : (card['question'] ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tap to ${_showAnswer ? 'see question' : 'reveal answer'}',
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _discardCard,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withAlpha(60)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, color: Colors.redAccent, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Discard',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _keepCard,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.deepPurpleAccent.withAlpha(60)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: Colors.deepPurpleAccent, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Keep',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration, color: Colors.deepPurpleAccent, size: 48),
          const SizedBox(height: 12),
          const Text(
            'All Cards Reviewed!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You kept ${_keptCards.length} out of ${_flashcards.length} cards',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (_keptCards.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kept Cards:',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._keptCards.map((card) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Q: ${card['question']}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    ).animate().fade(delay: 200.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildSavedItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.style, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['count']} cards',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['content'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedSets.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'auto_flashcards',
                    _savedSets.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
