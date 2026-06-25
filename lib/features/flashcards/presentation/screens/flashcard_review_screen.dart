import 'package:flutter/material.dart';

class FlashcardReviewScreen extends StatefulWidget {
  final int deckIndex;
  final Map<String, dynamic> deck;
  const FlashcardReviewScreen({
    super.key,
    required this.deckIndex,
    required this.deck,
  });

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen>
    with SingleTickerProviderStateMixin {
  late List<dynamic> _cards;
  late PageController _pageController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final Set<int> _knownCards = {};
  final Set<int> _unknownCards = {};

  @override
  void initState() {
    super.initState();
    _cards = widget.deck['cards'] as List<dynamic>;
    _pageController = PageController();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    _isFlipped = !_isFlipped;
  }

  void _markKnown() {
    _knownCards.add(_currentIndex);
    _unknownCards.remove(_currentIndex);
    _nextCard();
  }

  void _markUnknown() {
    _unknownCards.add(_currentIndex);
    _knownCards.remove(_currentIndex);
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeReview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review Complete!'),
        content: Text(
          'Known: ${_knownCards.length} / ${_cards.length}\n'
          'Needs Review: ${_unknownCards.length} / ${_cards.length}',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck['name'] ?? 'Flashcards'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${_cards.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _isFlipped = false;
                  _flipController.reset();
                });
              },
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final isFront = _flipAnimation.value < 0.5;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 0, 0)
                            ..rotateY(_flipAnimation.value * 3.14159),
                          child: isFront
                              ? _buildCardSide(
                                  card['front'] as String,
                                  'Tap to reveal answer',
                                  theme,
                                  const Color(0xFF1E1E1E),
                                )
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateY(3.14159),
                                  child: _buildCardSide(
                                    card['back'] as String,
                                    'Tap to see question',
                                    theme,
                                    Colors.deepPurple.withAlpha(30),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          _buildActionBar(theme),
        ],
      ),
    );
  }

  Widget _buildCardSide(String text, String hint, ThemeData theme, Color bgColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app,
                size: 24,
                color: Colors.white.withAlpha(80),
              ),
              const SizedBox(height: 20),
              Text(
                text,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                hint,
                style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(80)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    final isLastCard = _currentIndex >= _cards.length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
            icon: Icons.close,
            label: 'Again',
            color: Colors.redAccent,
            onTap: _markUnknown,
          ),
          _actionButton(
            icon: Icons.check,
            label: isLastCard ? 'Finish' : 'Good',
            color: Colors.greenAccent,
            onTap: isLastCard ? _completeReview : _markKnown,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
