import 'package:flutter/material.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';

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
      builder: (dialogContext) => Theme(
        data: AppTheme.darkTheme,
        child: Builder(
          builder: (ctx) => AlertDialog(
            title: Text('Review Complete!', style: ctx.text.titleMedium),
            content: Text(
              'Known: ${_knownCards.length} / ${_cards.length}\n'
              'Needs Review: ${_unknownCards.length} / ${_cards.length}',
              style: ctx.text.bodyMedium,
            ),
            actions: [
              NexusButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: widget.deck['name'] ?? 'Flashcards',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.md),
          child: Center(
            child: Text(
              '${_currentIndex + 1}/${_cards.length}',
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
                  padding: const EdgeInsets.all(AppSpace.lg),
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
                                  context,
                                  t.surface,
                                )
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateY(3.14159),
                                  child: _buildCardSide(
                                    card['back'] as String,
                                    'Tap to see question',
                                    context,
                                    t.primaryTint,
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
          _buildActionBar(context),
        ],
      ),
    );
  }

  Widget _buildCardSide(
    String text,
    String hint,
    BuildContext context,
    Color bgColor,
  ) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: t.border),
        boxShadow: AppElevation.e2(t.shadow),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app,
                size: 24,
                color: t.inkFaint,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                text,
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                hint,
                style: context.text.labelSmall?.copyWith(color: t.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final t = context.tokens;
    final isLastCard = _currentIndex >= _cards.length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(
            context,
            icon: Icons.close,
            label: 'Again',
            color: t.statusAbsent,
            onTap: _markUnknown,
          ),
          _actionButton(
            context,
            icon: Icons.check,
            label: isLastCard ? 'Finish' : 'Good',
            color: t.statusPresent,
            onTap: isLastCard ? _completeReview : _markKnown,
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpace.xs),
            Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
