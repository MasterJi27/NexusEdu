import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _myScore = 0;
  int _botScore = 0;
  Timer? _botTimer;

  final List<Map<String, dynamic>> _questions = [
    {'q': 'What is the primary function of a CNN?', 'opts': ['Text data', 'Image recognition', 'Sorting', 'Memory'], 'a': 1},
    {'q': 'What does "O(1)" mean?', 'opts': ['Linear', 'Quadratic', 'Constant', 'Exponential'], 'a': 2},
    {'q': 'Which language is used for Flutter?', 'opts': ['Java', 'Kotlin', 'Dart', 'Swift'], 'a': 2},
    {'q': 'What is a Widget in Flutter?', 'opts': ['A UI component', 'A database', 'A network request', 'A variable'], 'a': 0},
    {'q': 'Which state management is NOT native?', 'opts': ['setState', 'InheritedWidget', 'Redux', 'ValueNotifier'], 'a': 2},
  ];

  @override
  void initState() {
    super.initState();
    _startBot();
  }

  void _startBot() {
    _botTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_botScore < _questions.length && _currentQuestionIndex < _questions.length) {
        setState(() {
          // Bot has 80% chance to score
          if (DateTime.now().millisecond % 10 < 8) {
            _botScore++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _submitAnswer(int index) {
    if (_currentQuestionIndex >= _questions.length) return;
    
    if (index == _questions[_currentQuestionIndex]['a']) {
      setState(() => _myScore++);
    }
    
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      setState(() => _currentQuestionIndex++); // mark finished
      _showResults();
    }
  }

  void _showResults() {
    _botTimer?.cancel();
    final won = _myScore >= _botScore;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(won ? Icons.emoji_events : Icons.sentiment_dissatisfied, 
                 size: 80, color: won ? Colors.amber : Colors.grey),
            const SizedBox(height: 16),
            Text(won ? 'VICTORY!' : 'DEFEAT', 
                 style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: won ? Colors.amber : Colors.grey)),
            const SizedBox(height: 8),
            Text('You: $_myScore  |  Bot: $_botScore', style: const TextStyle(fontSize: 20)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Return to Dashboard', style: TextStyle(fontSize: 18)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finished = _currentQuestionIndex >= _questions.length;
    final q = finished ? _questions.last : _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Battle vs AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.withAlpha(50),
      ),
      body: Column(
        children: [
          // Split Screen Racing Bars
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOU', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _myScore / _questions.length,
                          color: Colors.blueAccent,
                          backgroundColor: Colors.blueAccent.withAlpha(30),
                          minHeight: 16,
                        ),
                      ).animate(target: _myScore.toDouble()).shimmer(),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('VS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, fontStyle: FontStyle.italic)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('AI BOT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _botScore / _questions.length,
                          color: Colors.redAccent,
                          backgroundColor: Colors.redAccent.withAlpha(30),
                          minHeight: 16,
                        ),
                      ).animate(target: _botScore.toDouble()).shimmer(color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: finished ? const Center(child: CircularProgressIndicator()) : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: Text(
                        q['q'],
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.3),
                        textAlign: TextAlign.center,
                      ).animate(key: ValueKey(_currentQuestionIndex)).fade().scale(),
                    ),
                  ),
                  ...(q['opts'] as List<String>).asMap().entries.map((entry) {
                    final idx = entry.key;
                    final text = entry.value;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () => _submitAnswer(idx),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50), width: 2),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8)],
                          ),
                          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        ),
                      ),
                    ).animate(key: ValueKey('$_currentQuestionIndex-$idx')).fade(delay: (50 * idx).ms).slideY(begin: 0.2);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
