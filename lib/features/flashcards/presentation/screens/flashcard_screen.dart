import 'dart:math';
import 'package:flutter/material.dart';

class Flashcard {
  final String front;
  final String back;
  final String subject;
  bool known;
  bool reviewed;

  Flashcard({
    required this.front,
    required this.back,
    required this.subject,
    this.known = false,
    this.reviewed = false,
  });
}

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<Flashcard> _cards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  String _selectedSubject = 'All';

  @override
  void initState() {
    super.initState();
    _cards = _getCards();
    _cards.shuffle();
  }

  List<Flashcard> _getCards() {
    return [
      Flashcard(front: 'What is Ohm\'s Law?', back: 'V = IR\nVoltage = Current × Resistance', subject: 'Physics'),
      Flashcard(front: 'What is the SI unit of Force?', back: 'Newton (N)\n1 N = 1 kg⋅m/s²', subject: 'Physics'),
      Flashcard(front: 'State Newton\'s Second Law', back: 'F = ma\nForce = Mass × Acceleration', subject: 'Physics'),
      Flashcard(front: 'What is Momentum?', back: 'p = mv\nMomentum = Mass × Velocity', subject: 'Physics'),
      Flashcard(front: 'What is the chemical formula for Water?', back: 'H₂O\n2 Hydrogen + 1 Oxygen', subject: 'Chemistry'),
      Flashcard(front: 'What is pH scale range?', back: '0 to 14\n7 = Neutral, <7 = Acidic, >7 = Basic', subject: 'Chemistry'),
      Flashcard(front: 'What is Avogadro\'s Number?', back: '6.022 × 10²³\nParticles in 1 mole of substance', subject: 'Chemistry'),
      Flashcard(front: 'What is a Covalent Bond?', back: 'Bond formed by sharing electrons\nbetween non-metal atoms', subject: 'Chemistry'),
      Flashcard(front: 'What is the derivative of xⁿ?', back: 'nxⁿ⁻¹\nPower Rule: bring down n, reduce power by 1', subject: 'Mathematics'),
      Flashcard(front: 'What is the formula for Area of Circle?', back: 'A = πr²\nπ ≈ 3.14159', subject: 'Mathematics'),
      Flashcard(front: 'What is integration of 1/x?', back: 'ln|x| + C\nNatural logarithm', subject: 'Mathematics'),
      Flashcard(front: 'What is Pythagoras Theorem?', back: 'a² + b² = c²\nHypotenuse² = Sum of squares of sides', subject: 'Mathematics'),
      Flashcard(front: 'What is the powerhouse of the cell?', back: 'Mitochondria\nProduces ATP (energy)', subject: 'Biology'),
      Flashcard(front: 'What is DNA?', back: 'Deoxyribonucleic Acid\nCarries genetic information', subject: 'Biology'),
      Flashcard(front: 'What is Photosynthesis?', back: '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂\nPlants make food using sunlight', subject: 'Biology'),
      Flashcard(front: 'What is Natural Selection?', back: 'Survival of the fittest\nOrganisms adapted to environment survive and reproduce', subject: 'Biology'),
    ];
  }

  List<Flashcard> get _filteredCards {
    if (_selectedSubject == 'All') return _cards;
    return _cards.where((c) => c.subject == _selectedSubject).toList();
  }

  void _nextCard() {
    setState(() {
      _showAnswer = false;
      _currentIndex = (_currentIndex + 1) % _filteredCards.length;
    });
  }

  void _prevCard() {
    setState(() {
      _showAnswer = false;
      _currentIndex = (_currentIndex - 1 + _filteredCards.length) % _filteredCards.length;
    });
  }

  void _markKnown() {
    final card = _filteredCards[_currentIndex];
    setState(() {
      card.known = true;
      card.reviewed = true;
    });
    _nextCard();
  }

  void _markUnknown() {
    final card = _filteredCards[_currentIndex];
    setState(() {
      card.known = false;
      card.reviewed = true;
    });
    _nextCard();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCards;
    if (filtered.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F13),
          title: const Text('Flashcards', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('No cards available', style: TextStyle(color: Colors.white54))),
      );
    }

    final card = filtered[_currentIndex];
    final knownCount = filtered.where((c) => c.known).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text('Flashcards', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${filtered.length}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'Physics', 'Chemistry', 'Mathematics', 'Biology'].map((s) {
                final isSelected = _selectedSubject == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: Colors.deepPurpleAccent,
                    backgroundColor: Colors.white10,
                    onSelected: (v) => setState(() {
                      _selectedSubject = s;
                      _currentIndex = 0;
                      _showAnswer = false;
                    }),
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: filtered.isNotEmpty ? knownCount / filtered.length : 0,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
              minHeight: 4,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mastered: $knownCount/${filtered.length}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                Text('${((knownCount / filtered.length) * 100).round()}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _showAnswer ? Colors.deepPurpleAccent.withOpacity(0.15) : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _showAnswer ? Colors.deepPurpleAccent.withOpacity(0.5) : Colors.white10,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSubjectColor(card.subject).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(card.subject, style: TextStyle(color: _getSubjectColor(card.subject), fontSize: 12)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _showAnswer ? 'Answer' : 'Question',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _showAnswer ? card.back : card.front,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _showAnswer ? 16 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _showAnswer ? 'Tap to see question' : 'Tap to reveal answer',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildButton(Icons.close, Colors.redAccent, 'Don\'t Know', _markUnknown),
                _buildButton(Icons.arrow_back, Colors.white54, 'Prev', _prevCard),
                _buildButton(Icons.shuffle, Colors.orangeAccent, 'Shuffle', () {
                  setState(() {
                    _cards.shuffle();
                    _currentIndex = 0;
                    _showAnswer = false;
                  });
                }),
                _buildButton(Icons.arrow_forward, Colors.white54, 'Next', _nextCard),
                _buildButton(Icons.check, Colors.greenAccent, 'Know It', _markKnown),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Physics': return Colors.blueAccent;
      case 'Chemistry': return Colors.greenAccent;
      case 'Mathematics': return Colors.orangeAccent;
      case 'Biology': return Colors.pinkAccent;
      default: return Colors.deepPurpleAccent;
    }
  }
}
