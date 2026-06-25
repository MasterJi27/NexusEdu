import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:nexus_edu/core/services/question_bank_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdaptiveQuizScreen extends StatefulWidget {
  const AdaptiveQuizScreen({super.key});

  @override
  State<AdaptiveQuizScreen> createState() => _AdaptiveQuizScreenState();
}

class _AdaptiveQuizScreenState extends State<AdaptiveQuizScreen> {
  String _selectedSubject = 'physics';
  String _selectedChapter = 'All';
  bool _isLoading = false;
  bool _quizStarted = false;

  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _difficulty = 1;
  double _eloRating = 1200;
  int _timeLeft = 0;
  Timer? _timer;
  int? _selectedAnswer;
  bool _answered = false;
  List<int> _difficultyJourney = [];
  List<double> _eloJourney = [];
  List<Map<String, dynamic>> _results = [];

  final Map<String, List<String>> _chaptersBySubject = {
    'physics': [
      'All',
      'Motion',
      'Force and Laws of Motion',
      'Work Energy and Power',
      'Light - Reflection and Refraction',
      'Gravitation',
      'Current Electricity',
    ],
    'chemistry': [
      'All',
      'Acids Bases and Salts',
      'Chemical Bonding',
      'Structure of the Atom',
      'Carbon and its Compounds',
      'Chemical Reactions and Equations',
    ],
    'maths': [
      'All',
      'Trigonometry',
      'Quadratic Equations',
      'Arithmetic Progressions',
      'Calculus',
      'Probability',
    ],
    'biology': [
      'All',
      'Cell Biology',
      'Life Processes',
      'Heredity and Evolution',
      'Control and Coordination',
      'Reproduction',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('adaptive_quiz_results') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'adaptive_quiz_results',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  void _loadQuestions() {
    final chapter = _selectedChapter == 'All' ? null : _selectedChapter;
    _questions = QuestionBankLocal.getQuestions(
      _selectedSubject,
      chapter: chapter,
      count: 20,
      difficulty: _difficulty,
    );
    if (_questions.isEmpty) {
      _questions = QuestionBankLocal.getQuestions(
        _selectedSubject,
        count: 20,
        difficulty: 3,
      );
    }
  }

  Future<void> _startQuiz() async {
    setState(() {
      _isLoading = true;
    });

    _loadQuestions();

    setState(() {
      _quizStarted = true;
      _isLoading = false;
      _currentIndex = 0;
      _score = 0;
      _streak = 0;
      _difficulty = 1;
      _eloRating = 1200;
      _selectedAnswer = null;
      _answered = false;
      _difficultyJourney = [1];
      _eloJourney = [1200];
    });
    _startTimer();
  }

  void _startTimer() {
    _timeLeft = 600;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _finishQuiz();
      }
    });
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final correct = _questions[_currentIndex]['correct'] as int;
    final isCorrect = index == correct;

    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (isCorrect) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
      _difficulty =
          LocalComputation.adaptiveDifficulty(_difficulty, isCorrect, _streak);
      _eloRating = LocalComputation.eloRating(
        _eloRating,
        800 + (_difficulty * 100).toDouble(),
        won: isCorrect,
      );
      _difficultyJourney.add(_difficulty);
      _eloJourney.add(_eloRating);
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _timer?.cancel();
    final percentage =
        _questions.isEmpty ? 0 : (_score / _questions.length * 100).round();

    final result = {
      'subject': _selectedSubject,
      'chapter': _selectedChapter,
      'score': _score,
      'total': _questions.length,
      'percentage': percentage,
      'eloRating': _eloRating.round(),
      'maxStreak': _streak,
      'difficultyJourney': _difficultyJourney,
      'eloJourney': _eloJourney.map((e) => e.round()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
    _showResultsDialog(result);
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    final pct = result['percentage'] as int;
    final journey = List<int>.from(result['difficultyJourney'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              pct >= 70 ? Icons.emoji_events : Icons.insights,
              color: pct >= 70 ? Colors.amberAccent : Colors.deepPurpleAccent,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Quiz Complete!',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _resultRow('Score', '${result['score']}/${result['total']}'),
              const SizedBox(height: 8),
              _resultRow('Accuracy', '$pct%'),
              const SizedBox(height: 8),
              _resultRow('Final Elo', '${result['eloRating']}'),
              const SizedBox(height: 8),
              _resultRow('Max Streak', '${result['maxStreak']}'),
              const SizedBox(height: 16),
              const Text(
                'Difficulty Journey',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: CustomPaint(
                  size: const Size(double.infinity, 60),
                  painter: _DifficultyChartPainter(journey),
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
                _quizStarted = false;
                _questions.clear();
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

  String _difficultyLabel(int d) {
    switch (d) {
      case 1:
        return 'Easy';
      case 2:
        return 'Medium';
      case 3:
        return 'Hard';
      case 4:
        return 'Expert';
      case 5:
        return 'Master';
      default:
        return 'Easy';
    }
  }

  Color _difficultyColor(int d) {
    switch (d) {
      case 1:
        return Colors.greenAccent;
      case 2:
        return Colors.orangeAccent;
      case 3:
        return Colors.redAccent;
      case 4:
        return Colors.purpleAccent;
      case 5:
        return Colors.amberAccent;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Adaptive Quiz Engine',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _quizStarted ? _buildQuizView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubjectSelector(),
          const SizedBox(height: 16),
          _buildChapterSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startQuiz,
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
                _isLoading ? 'Loading...' : 'Start Quiz',
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

  Widget _buildSubjectSelector() {
    return _buildSelectorRow(
      'Subject',
      ['physics', 'chemistry', 'maths', 'biology'],
      _selectedSubject,
      (val) => setState(() {
        _selectedSubject = val!;
        _selectedChapter = 'All';
      }),
    );
  }

  Widget _buildChapterSelector() {
    final chapters = _chaptersBySubject[_selectedSubject] ?? ['All'];
    return _buildSelectorRow(
      'Chapter',
      chapters,
      _selectedChapter,
      (val) => setState(() => _selectedChapter = val!),
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
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    opt.toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  Widget _buildQuizView() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('No questions available',
            style: TextStyle(color: Colors.white54)),
      );
    }
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final progress = (_currentIndex + 1) / _questions.length;
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final timerColor = _timeLeft > 120
        ? Colors.greenAccent
        : _timeLeft > 30
            ? Colors.orangeAccent
            : Colors.redAccent;

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
                  Text(
                    'Q${_currentIndex + 1}/${_questions.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: timerColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: timerColor, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$minutes:${seconds.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: timerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statChip('Score', '$_score', Colors.tealAccent),
                  _statChip('Streak', '$_streak', Colors.amberAccent),
                  _statChip('Elo', '${_eloRating.round()}', Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Difficulty: ',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ...List.generate(5, (i) {
                    final active = i < _difficulty;
                    return Icon(
                      active ? Icons.star : Icons.star_border,
                      color: active ? _difficultyColor(_difficulty) : Colors.white24,
                      size: 18,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    _difficultyLabel(_difficulty),
                    style: TextStyle(
                      color: _difficultyColor(_difficulty),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withAlpha(15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q['q'] ?? '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(options.length, (i) {
                  final isCorrect = i == q['correct'];
                  final isSelected = _selectedAnswer == i;
                  Color bgColor = const Color(0xFF1E1E1E);
                  Color borderColor = Colors.white.withAlpha(15);
                  if (_answered) {
                    if (isCorrect) {
                      bgColor = Colors.green.withAlpha(30);
                      borderColor = Colors.greenAccent;
                    } else if (isSelected && !isCorrect) {
                      bgColor = Colors.red.withAlpha(30);
                      borderColor = Colors.redAccent;
                    }
                  }
                  return GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.deepPurpleAccent.withAlpha(40)
                                  : Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.deepPurpleAccent
                                      : Colors.white.withAlpha(150),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              options[i],
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: Duration(milliseconds: 50 * i));
                }),
                if (_answered) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _nextQuestion,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentIndex < _questions.length - 1
                            ? 'Next Question'
                            : 'Finish Quiz',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: color.withAlpha(180), fontSize: 11)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
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
            child: const Icon(Icons.psychology,
                color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['subject']} - ${r['chapter']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']}/${r['total']} (${r['percentage']}%) • Elo: ${r['eloRating']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${r['percentage']}%',
            style: TextStyle(
              color: (r['percentage'] as int) >= 70
                  ? Colors.greenAccent
                  : (r['percentage'] as int) >= 50
                      ? Colors.orangeAccent
                      : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyChartPainter extends CustomPainter {
  final List<int> journey;

  _DifficultyChartPainter(this.journey);

  @override
  void paint(Canvas canvas, Size size) {
    if (journey.isEmpty) return;
    final paint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (journey.length - 1).clamp(1, 100);

    for (int i = 0; i < journey.length; i++) {
      final x = i * stepX;
      final y = size.height - (journey[i] / 5 * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    for (int i = 0; i < journey.length; i++) {
      final x = i * stepX;
      final y = size.height - (journey[i] / 5 * size.height);
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.deepPurpleAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
