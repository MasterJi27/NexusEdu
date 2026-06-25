import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  String _examType = 'JEE';
  String _selectedSubject = 'Physics';
  int _durationMinutes = 60;
  bool _isLoading = false;
  bool _testStarted = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  Set<int> _markedForReview = {};
  int _score = 0;
  int _timeLeft = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _results = [];

  final Map<String, List<String>> _subjectsByExam = {
    'JEE': ['Physics', 'Chemistry', 'Maths'],
    'NEET': ['Physics', 'Chemistry', 'Biology'],
    'CBSE Board': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English'],
    'State Board': ['Physics', 'Chemistry', 'Biology', 'Maths'],
  };

  @override
  void initState() {
    super.initState();
    _selectedSubject = _subjectsByExam[_examType]!.first;
    _loadResults();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('mock_test_results') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'mock_test_results',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _startTest() async {
    setState(() {
      _isLoading = true;
      _questions = [];
    });

    final prompt = "Generate a mock $_examType test for $_selectedSubject. "
        "Duration: $_durationMinutes minutes. "
        "Return exactly 20 MCQs. Each object must have: "
        "\"question\" (string), \"options\" (array of 4 strings), "
        "\"correctIndex\" (int 0-3), \"explanation\" (string), "
        "\"topic\" (string). "
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
        _testStarted = true;
        _currentIndex = 0;
        _score = 0;
        _selectedAnswer = null;
        _answered = false;
        _markedForReview = {};
      });
      _startTimer();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timeLeft = _durationMinutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  void _autoSubmit() {
    _finishTest();
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentIndex]['correctIndex']) _score++;
    });
  }

  void _toggleMarkForReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
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
      _finishTest();
    }
  }

  void _finishTest() {
    _timer?.cancel();
    final percentage = (_score / _questions.length * 100).round();

    final result = {
      'exam': _examType,
      'subject': _selectedSubject,
      'score': _score,
      'total': _questions.length,
      'percentage': percentage,
      'duration': _durationMinutes,
      'markedReview': _markedForReview.length,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
    _showResultsDialog(result);
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    final pct = result['percentage'] as int;
    final timeTaken = _durationMinutes - (_timeLeft ~/ 60);

    final subjectScores = <String, Map<String, int>>{};
    for (final q in _questions) {
      final topic = q['topic'] ?? 'Unknown';
      subjectScores.putIfAbsent(topic, () => {'correct': 0, 'total': 0});
      subjectScores[topic]!['total'] = subjectScores[topic]!['total']! + 1;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              pct >= 70 ? Icons.emoji_events : Icons.assessment,
              color: pct >= 70 ? Colors.amberAccent : Colors.deepPurpleAccent,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Test Complete!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              _resultRow('Time Taken', '$timeTaken min'),
              const SizedBox(height: 8),
              _resultRow('Marked for Review', '${result['markedReview']}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Topic-wise Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...subjectScores.entries.take(6).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.value['correct']}/${e.value['total']}',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
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
                _testStarted = false;
                _questions.clear();
              });
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
        title: Text(
          _testStarted ? 'Mock Test - $_examType' : 'Mock Test',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_testStarted)
            TextButton(
              onPressed: _finishTest,
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
      body: _testStarted ? _buildTestView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExamTypeSelector(),
          const SizedBox(height: 16),
          _buildSubjectSelector(),
          const SizedBox(height: 16),
          _buildDurationSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startTest,
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
                _isLoading ? 'Preparing Test...' : 'Start Mock Test',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildExamTypeSelector() {
    return _buildSelectorRow(
      'Exam Type',
      ['JEE', 'NEET', 'CBSE Board', 'State Board'],
      _examType,
      (val) => setState(() {
        _examType = val!;
        _selectedSubject = _subjectsByExam[_examType]!.first;
      }),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildSelectorRow(
      'Subject',
      _subjectsByExam[_examType]!,
      _selectedSubject,
      (val) => setState(() => _selectedSubject = val!),
    );
  }

  Widget _buildDurationSelector() {
    return _buildSelectorRow(
      'Duration',
      ['60 min', '120 min', '180 min'],
      '$_durationMinutes min',
      (val) => setState(() {
        _durationMinutes = int.parse(val!.split(' ').first);
      }),
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

  Widget _buildTestView() {
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final progress = (_currentIndex + 1) / _questions.length;
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final timerColor =
        _timeLeft > 300 ? Colors.greenAccent : _timeLeft > 60 ? Colors.orangeAccent : Colors.redAccent;
    final isMarked = _markedForReview.contains(_currentIndex);

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q['question'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleMarkForReview,
                      icon: Icon(
                        isMarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isMarked ? Colors.amberAccent : Colors.white38,
                      ),
                      tooltip: 'Mark for Review',
                    ),
                  ],
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
                            : 'Submit Test',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildQuestionNavigator(),
      ],
    );
  }

  Widget _buildQuestionNavigator() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final isCurrent = index == _currentIndex;
          final isMarked = _markedForReview.contains(index);
          final isAnswered = index < _currentIndex || (index == _currentIndex && _answered);
          Color color;
          if (isCurrent) {
            color = Colors.deepPurpleAccent;
          } else if (isMarked) {
            color = Colors.amberAccent;
          } else if (isAnswered) {
            color = Colors.tealAccent;
          } else {
            color = Colors.white24;
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _currentIndex = index;
                _selectedAnswer = null;
                _answered = false;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
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
            child: const Icon(Icons.quiz, color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['exam']} - ${r['subject']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']}/${r['total']} (${r['percentage']}%) • ${r['duration']}min',
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
