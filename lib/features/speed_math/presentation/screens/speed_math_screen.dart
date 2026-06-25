import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeedMathScreen extends StatefulWidget {
  const SpeedMathScreen({super.key});

  @override
  State<SpeedMathScreen> createState() => _SpeedMathScreenState();
}

class _SpeedMathScreenState extends State<SpeedMathScreen> {
  String _selectedOperation = '+';
  String _selectedDifficulty = 'Easy';
  int _selectedTime = 60;
  bool _isLoading = false;
  bool _gameStarted = false;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _score = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _totalAnswered = 0;
  int _correctCount = 0;
  int _timeLeft = 0;
  Timer? _timer;

  String _currentQuestion = '';
  int _correctAnswer = 0;
  List<double> _scoreTimeline = [];
  List<Map<String, dynamic>> _results = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('speed_math_scores') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'speed_math_scores',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  int get _difficultyMultiplier {
    switch (_selectedDifficulty) {
      case 'Easy':
        return 10;
      case 'Medium':
        return 100;
      case 'Hard':
        return 1000;
      default:
        return 10;
    }
  }

  void _generateProblem() {
    final max = _difficultyMultiplier;
    int a = _random.nextInt(max) + 1;
    int b = _random.nextInt(max) + 1;

    switch (_selectedOperation) {
      case '+':
        _correctAnswer = a + b;
        _currentQuestion = '$a + $b = ?';
        break;
      case '-':
        if (b > a) {
          final temp = a;
          a = b;
          b = temp;
        }
        _correctAnswer = a - b;
        _currentQuestion = '$a - $b = ?';
        break;
      case '×':
        a = _random.nextInt(min(max, 30)) + 1;
        b = _random.nextInt(min(max, 30)) + 1;
        _correctAnswer = a * b;
        _currentQuestion = '$a × $b = ?';
        break;
      case '÷':
        b = _random.nextInt(min(max, 20)) + 1;
        final product = b * (_random.nextInt(min(max, 20)) + 1);
        _correctAnswer = product ~/ b;
        _currentQuestion = '$product ÷ $b = ?';
        break;
    }
  }

  Future<void> _startGame() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    _generateProblem();

    setState(() {
      _isLoading = false;
      _gameStarted = true;
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _totalAnswered = 0;
      _correctCount = 0;
      _scoreTimeline = [0];
      _answerController.clear();
    });
    _startTimer();
    _focusNode.requestFocus();
  }

  void _startTimer() {
    _timeLeft = _selectedTime;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _finishGame();
      }
    });
  }

  void _submitAnswer() {
    if (_answerController.text.trim().isEmpty) return;

    final userAnswer = int.tryParse(_answerController.text.trim());
    if (userAnswer == null) return;

    final isCorrect = userAnswer == _correctAnswer;

    setState(() {
      _totalAnswered++;
      if (isCorrect) {
        _correctCount++;
        _streak++;
        if (_streak > _maxStreak) _maxStreak = _streak;
        final streakBonus = _streak >= 5
            ? 3
            : _streak >= 3
                ? 2
                : 1;
        _score += 10 * streakBonus;
      } else {
        _streak = 0;
      }
      _scoreTimeline.add(_score.toDouble());
      _answerController.clear();
    });

    _generateProblem();
    _focusNode.requestFocus();
  }

  void _finishGame() {
    _timer?.cancel();
    final accuracy =
        _totalAnswered > 0 ? (_correctCount / _totalAnswered * 100).round() : 0;
    final avgTime = _totalAnswered > 0
        ? (_selectedTime / _totalAnswered).toStringAsFixed(1)
        : '0';

    final result = {
      'operation': _selectedOperation,
      'difficulty': _selectedDifficulty,
      'duration': _selectedTime,
      'score': _score,
      'correct': _correctCount,
      'total': _totalAnswered,
      'accuracy': accuracy,
      'maxStreak': _maxStreak,
      'avgTimePerQ': avgTime,
      'scoreTimeline': _scoreTimeline.map((e) => e.round()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();

    setState(() {});
    _showResultsDialog(result);
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    final acc = result['accuracy'] as int;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              acc >= 80 ? Icons.bolt : Icons.calculate,
              color: acc >= 80 ? Colors.amberAccent : Colors.deepPurpleAccent,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Time\'s Up!',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _resultRow('Score', '${result['score']}'),
              const SizedBox(height: 8),
              _resultRow('Accuracy', '$acc%'),
              const SizedBox(height: 8),
              _resultRow('Correct', '${result['correct']}/${result['total']}'),
              const SizedBox(height: 8),
              _resultRow('Max Streak', '${result['maxStreak']}'),
              const SizedBox(height: 8),
              _resultRow('Avg Time/Q', '${result['avgTimePerQ']}s'),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: CustomPaint(
                  size: const Size(double.infinity, 60),
                  painter: _SpeedChartPainter(
                    List<int>.from(result['scoreTimeline'] ?? []),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _gameStarted = false;
              });
            },
            child:
                const Text('OK', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withAlpha(150))),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Speed Math Challenge',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _gameStarted ? _buildGameView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOperationSelector(),
          const SizedBox(height: 16),
          _buildDifficultySelector(),
          const SizedBox(height: 16),
          _buildTimeSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startGame,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
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
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isLoading ? 'Preparing...' : 'Start Challenge',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_results.length.clamp(0, 10), (i) {
              return _buildResultCard(_results[i]);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationSelector() {
    return _buildSelectorRow(
      'Operation',
      ['+', '-', '×', '÷'],
      _selectedOperation,
      (val) => setState(() => _selectedOperation = val!),
    );
  }

  Widget _buildDifficultySelector() {
    return _buildSelectorRow(
      'Difficulty',
      ['Easy', 'Medium', 'Hard'],
      _selectedDifficulty,
      (val) => setState(() => _selectedDifficulty = val!),
    );
  }

  Widget _buildTimeSelector() {
    return _buildSelectorRow(
      'Timer',
      ['60', '120', '300'],
      '$_selectedTime',
      (val) => setState(() => _selectedTime = int.parse(val!)),
    );
  }

  Widget _buildSelectorRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurpleAccent.withAlpha(40)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(15),
                    ),
                  ),
                  child: Text(
                    label == 'Timer' ? '${opt}s' : opt,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildGameView() {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final timerColor = _timeLeft > 30
        ? Colors.greenAccent
        : _timeLeft > 10
            ? Colors.orangeAccent
            : Colors.redAccent;
    final accuracy = _totalAnswered > 0
        ? (_correctCount / _totalAnswered * 100).round()
        : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: timerColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: timerColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '$minutes:${seconds.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: timerColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$_selectedOperation  $_selectedDifficulty',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statBlock('Score', '$_score', Colors.tealAccent),
                  _statBlock('Streak', '$_streak', Colors.amberAccent),
                  _statBlock('Accuracy', '$accuracy%', Colors.purpleAccent),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentQuestion,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _answerController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: '?',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(50)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Colors.deepPurpleAccent.withAlpha(80)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Colors.deepPurpleAccent.withAlpha(80)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Colors.deepPurpleAccent, width: 2),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                      ),
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: FilledButton(
                      onPressed: _submitAnswer,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
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

  Widget _statBlock(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.speed,
                color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['operation']} • ${r['difficulty']} • ${r['duration']}s',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']} • Accuracy: ${r['accuracy']}% • Streak: ${r['maxStreak']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${r['score']}',
            style: TextStyle(
              color: (r['score'] as int) >= 200
                  ? Colors.greenAccent
                  : (r['score'] as int) >= 100
                      ? Colors.orangeAccent
                      : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  final List<int> scores;

  _SpeedChartPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final maxScore = scores.reduce(max).toDouble();
    if (maxScore == 0) return;

    final paint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (scores.length - 1).clamp(1, 100);

    for (int i = 0; i < scores.length; i++) {
      final x = i * stepX;
      final y = size.height - (scores[i] / maxScore * size.height * 0.8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
