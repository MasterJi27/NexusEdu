import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  String _selectedSubject = 'Physics';
  String _selectedTopic = 'Electrostatics';
  String _difficulty = 'Mixed';
  int _questionCount = 10;
  bool _isLoading = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _timeLeft = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _savedQuestions = [];

  final Map<String, List<String>> _topicsBySubject = {
    'Physics': [
      'Electrostatics', 'Current Electricity', 'Magnetism', 'Optics',
      'Modern Physics', 'Thermodynamics', 'Waves', 'Mechanics',
    ],
    'Chemistry': [
      'Organic Chemistry', 'Inorganic Chemistry', 'Physical Chemistry',
      'Chemical Bonding', 'Coordination Compounds', 'p-Block Elements',
    ],
    'Biology': [
      'Cell Biology', 'Genetics', 'Ecology', 'Human Physiology',
      'Plant Biology', 'Evolution', 'Biotechnology',
    ],
    'Maths': [
      'Calculus', 'Algebra', 'Coordinate Geometry', 'Trigonometry',
      'Probability', 'Statistics', 'Vectors', 'Matrices',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedTopic = _topicsBySubject[_selectedSubject]!.first;
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('question_bank') ?? [];
    setState(() {
      _savedQuestions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'question_bank',
      _savedQuestions.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _generateQuestions() async {
    setState(() {
      _isLoading = true;
      _questions = [];
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
    });

    final prompt = "Generate $_questionCount MCQs on $_selectedSubject - $_selectedTopic. "
        "Difficulty: $_difficulty. "
        "Return a JSON array. Each object must have: "
        "\"question\" (string), \"options\" (array of 4 strings), "
        "\"correctIndex\" (int 0-3), \"explanation\" (string). "
        "No markdown, no code fences. Raw JSON only.";

    final result = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    try {
      String jsonStr = result.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        jsonStr = lines.join('\n').trim();
      }

      final List<dynamic> parsed = json.decode(jsonStr);
      setState(() {
        _questions = parsed
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
      });
      _startTimer();

      _savedQuestions.insert(0, {
        'subject': _selectedSubject,
        'topic': _selectedTopic,
        'count': _questions.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (_savedQuestions.length > 20) _savedQuestions.removeLast();
      _saveQuestions();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timeLeft = _questions.length * 60;
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
    _timer?.cancel();
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentIndex]['correctIndex']) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _timer?.cancel();
    final pct = (_score / _questions.length * 100).round();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              pct >= 70 ? Icons.emoji_events : Icons.trending_up,
              color: pct >= 70 ? Colors.amberAccent : Colors.deepPurpleAccent,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Quiz Complete!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Score', '$_score / ${_questions.length}'),
            const SizedBox(height: 8),
            _resultRow('Accuracy', '$pct%'),
            const SizedBox(height: 8),
            _resultRow('Topic', '$_selectedSubject - $_selectedTopic'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _questions.clear());
            },
            child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
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
          'Question Bank',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _questions.isNotEmpty ? _buildQuizView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubjectSelector(),
          const SizedBox(height: 12),
          _buildTopicSelector(),
          const SizedBox(height: 12),
          _buildDifficultySelector(),
          const SizedBox(height: 12),
          _buildCountSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _generateQuestions,
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
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Generating...' : 'Generate Questions',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_savedQuestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Recent Sets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_savedQuestions.length.clamp(0, 8), (i) {
              return _buildSavedItem(_savedQuestions[i], i);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildChipRow(
      'Subject',
      ['Physics', 'Chemistry', 'Biology', 'Maths'],
      _selectedSubject,
      (val) => setState(() {
        _selectedSubject = val!;
        _selectedTopic = _topicsBySubject[_selectedSubject]!.first;
      }),
    );
  }

  Widget _buildTopicSelector() {
    return _buildChipRow(
      'Topic',
      _topicsBySubject[_selectedSubject]!,
      _selectedTopic,
      (val) => setState(() => _selectedTopic = val!),
    );
  }

  Widget _buildDifficultySelector() {
    return _buildChipRow(
      'Difficulty',
      ['Easy', 'Medium', 'Hard', 'Mixed'],
      _difficulty,
      (val) => setState(() => _difficulty = val!),
    );
  }

  Widget _buildCountSelector() {
    return _buildChipRow(
      'Number of Questions',
      ['5', '10', '20', '50'],
      _questionCount.toString(),
      (val) => setState(() => _questionCount = int.parse(val!)),
    );
  }

  Widget _buildChipRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                    opt,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final progress = (_currentIndex + 1) / _questions.length;
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final timerColor =
        _timeLeft > 120 ? Colors.greenAccent : _timeLeft > 30 ? Colors.orangeAccent : Colors.redAccent;

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
                  Text(
                    'Score: $_score',
                    style: const TextStyle(
                        color: Colors.tealAccent, fontWeight: FontWeight.bold),
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
                  q['question'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(options.length, (i) {
                  final isCorrect = i == q['correctIndex'];
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withAlpha(30)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb,
                            color: Colors.amberAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q['explanation'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            : 'Finish',
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
          Icon(Icons.history, color: Colors.white.withAlpha(80), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['subject']} - ${item['topic']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item['count']} questions',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedQuestions.removeAt(index));
              _saveQuestions();
            },
          ),
        ],
      ),
    );
  }
}
