import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/daily_quiz_service.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  final _quizService = DailyQuizService();
  final _gamification = GamificationService();
  late List<DailyQuizQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedAnswer;
  bool _showExplanation = false;
  int _timeLeft = 30;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _questions = _quizService.todayQuestions;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0 && !_answered) {
        setState(() => _timeLeft--);
      } else if (_timeLeft == 0 && !_answered) {
        _handleAnswer(-1);
      }
    });
  }

  void _handleAnswer(int index) {
    _timer?.cancel();
    setState(() {
      _answered = true;
      _selectedAnswer = index;
      _showExplanation = true;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
    _quizService.recordAnswer(_score);
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedAnswer = null;
        _showExplanation = false;
        _timeLeft = 30;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      _gamification.recordQuizCompletion(_score);
      setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return _buildResults();
    final q = _questions[_currentIndex];
    final isCorrect = _selectedAnswer == q.correctIndex;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text('Daily Quiz', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeLeft <= 10 ? Colors.redAccent.withOpacity(0.2) : Colors.deepPurpleAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '⏱ $_timeLeft s',
                  style: TextStyle(
                    color: _timeLeft <= 10 ? Colors.redAccent : Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Q${_currentIndex + 1}/${_questions.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Colors.deepPurpleAccent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Score: $_score',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getSubjectColor(q.subject).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(q.subject, style: TextStyle(color: _getSubjectColor(q.subject), fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.question,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(4, (i) {
                    final isSelected = _selectedAnswer == i;
                    final isCorrectOption = i == q.correctIndex;
                    Color bgColor = const Color(0xFF1E1E1E);
                    Color borderColor = Colors.white10;
                    Color textColor = Colors.white;

                    if (_answered) {
                      if (isCorrectOption) {
                        bgColor = Colors.greenAccent.withOpacity(0.15);
                        borderColor = Colors.greenAccent;
                        textColor = Colors.greenAccent;
                      } else if (isSelected && !isCorrectOption) {
                        bgColor = Colors.redAccent.withOpacity(0.15);
                        borderColor = Colors.redAccent;
                        textColor = Colors.redAccent;
                      }
                    } else if (isSelected) {
                      bgColor = Colors.deepPurpleAccent.withOpacity(0.15);
                      borderColor = Colors.deepPurpleAccent;
                    }

                    return GestureDetector(
                      onTap: _answered ? null : () => _handleAnswer(i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCorrectOption && _answered ? Colors.greenAccent : Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i),
                                  style: TextStyle(
                                    color: isCorrectOption && _answered ? Colors.white : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.options[i],
                                style: TextStyle(color: textColor, fontSize: 16),
                              ),
                            ),
                            if (_answered && isCorrectOption)
                              const Icon(Icons.check_circle, color: Colors.greenAccent),
                            if (_answered && isSelected && !isCorrectOption)
                              const Icon(Icons.cancel, color: Colors.redAccent),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_showExplanation) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.deepPurpleAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              q.explanation,
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_answered)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentIndex < _questions.length - 1 ? 'Next Question →' : 'See Results',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final percentage = (_score / _questions.length * 100).round();
    String message;
    String emoji;
    if (percentage >= 90) {
      message = 'Outstanding! You\'re a genius!';
      emoji = '🏆';
    } else if (percentage >= 70) {
      message = 'Great job! Keep it up!';
      emoji = '🎉';
    } else if (percentage >= 50) {
      message = 'Good effort! Room to improve.';
      emoji = '👍';
    } else {
      message = 'Keep practicing! You\'ll get better.';
      emoji = '💪';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'Quiz Complete!',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 32),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurpleAccent.withOpacity(0.15),
                  border: Border.all(color: Colors.deepPurpleAccent, width: 4),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_score/${_questions.length}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      Text('$percentage%', style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResultStat('Correct', '$_score', Colors.greenAccent),
                  _buildResultStat('Wrong', '${_questions.length - _score}', Colors.redAccent),
                  _buildResultStat('XP Earned', '+${_score * 20}', Colors.deepPurpleAccent),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
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
