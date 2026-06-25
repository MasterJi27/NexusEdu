import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TestPhase { setup, active, results }

class SelfTestScreen extends StatefulWidget {
  const SelfTestScreen({super.key});

  @override
  State<SelfTestScreen> createState() => _SelfTestScreenState();
}

class _SelfTestScreenState extends State<SelfTestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TestPhase _phase = TestPhase.setup;
  bool _isLoading = false;

  // Setup state
  String _selectedBoard = 'CBSE';
  int _selectedClass = 10;
  String _selectedSubject = 'Physics';
  String _chapterName = '';
  int _numQuestions = 10;
  String _difficulty = 'Mixed';
  String _timeLimit = '10 min';
  String _syllabusType = 'full';

  // Active test state
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];
  List<bool> _markedForReview = [];
  Timer? _timer;
  int _remainingSeconds = 600;
  int _totalTestSeconds = 600;
  String _testStatusMessage = '';

  // Results state
  int _score = 0;
  int _totalQuestions = 0;
  double _accuracy = 0;
  String _timeTaken = '';
  String _grade = '';
  List<Map<String, dynamic>> _questionResults = [];
  String _aiSuggestion = '';
  bool _showNavigator = false;

  // Constants
  static const Color _bgColor = Color(0xFF0F0F13);
  static const Color _cardColor = Color(0xFF1E1E1E);
  static const Color _accent = Colors.deepPurpleAccent;

  final List<String> _boards = ['CBSE', 'ICSE', 'State Board'];
  final List<int> _classes = [6, 7, 8, 9, 10, 11, 12];
  final List<String> _subjects = [
    'Physics',
    'Chemistry',
    'Biology',
    'Maths',
    'English',
    'Hindi',
    'Science',
    'Social Science',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  int _parseTimeLimit(String label) {
    switch (label) {
      case '5 min':
        return 300;
      case '10 min':
        return 600;
      case '15 min':
        return 900;
      case '30 min':
        return 1800;
      case '60 min':
        return 3600;
      case '90 min':
        return 5400;
      case '120 min':
        return 7200;
      default:
        return 0;
    }
  }

  Future<void> _startTest() async {
    final chapter =
        _tabController.index == 0 ? _chapterName : 'Full Syllabus';
    if (_tabController.index == 0 && chapter.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a chapter name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _testStatusMessage = 'Generating questions...';
    });

    try {
      final n = _tabController.index == 0
          ? _numQuestions
          : (int.tryParse(_numQuestions
                      .toString()
                      .replaceAll(r'[^0-9]', '')) ??
              20);
      final prompt =
          'Generate $n multiple choice questions about $chapter for class $_selectedClass $_selectedBoard board $_selectedSubject. '
          'Format as JSON array: [{"question": "string", "options": ["A", "B", "C", "D"], "correct": 0}] '
          'where correct is the index of the right answer (0-3). Only return the JSON array, nothing else.';

      final response = await AiService.sendMessageToTutor(prompt);

      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Invalid response format');
      }

      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> parsed = json.decode(jsonStr);

      final List<Map<String, dynamic>> questions = parsed.map((q) {
        return {
          'question': q['question'] ?? '',
          'options': List<String>.from(q['options'] ?? []),
          'correct': q['correct'] ?? 0,
        };
      }).toList();

      if (questions.isEmpty) throw Exception('No questions generated');

      setState(() {
        _questions = questions;
        _userAnswers = List<int?>.filled(questions.length, null);
        _markedForReview = List<bool>.filled(questions.length, false);
        _currentQuestionIndex = 0;
        _totalQuestions = questions.length;
        _phase = TestPhase.active;
        _isLoading = false;
        _showNavigator = false;
      });

      if (_tabController.index == 0) {
        _remainingSeconds = _parseTimeLimit(_timeLimit);
      } else {
        _remainingSeconds = _parseTimeLimit(_timeLimit);
      }
      _totalTestSeconds = _remainingSeconds;

      if (_remainingSeconds > 0) {
        _startTimer();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating questions: $e')),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _finishTest();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _finishTest() {
    _timer?.cancel();

    int correct = 0;
    final List<Map<String, dynamic>> results = [];

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final userAns = _userAnswers[i];
      final correctAns = q['correct'] as int;
      final isCorrect = userAns == correctAns;

      if (isCorrect) correct++;

      results.add({
        'question': q['question'],
        'options': q['options'],
        'correct': correctAns,
        'userAnswer': userAns,
        'isCorrect': isCorrect,
      });
    }

    final total = _questions.length;
    final acc = total > 0 ? (correct / total * 100) : 0.0;
    final elapsed = _totalTestSeconds - _remainingSeconds;
    final min = elapsed ~/ 60;
    final sec = elapsed % 60;

    String g;
    if (acc >= 90) {
      g = 'A+';
    } else if (acc >= 80) {
      g = 'A';
    } else if (acc >= 70) {
      g = 'B';
    } else if (acc >= 60) {
      g = 'C';
    } else if (acc >= 50) {
      g = 'D';
    } else {
      g = 'F';
    }

    setState(() {
      _score = correct;
      _accuracy = acc;
      _timeTaken = '${min}m ${sec}s';
      _grade = g;
      _questionResults = results;
      _phase = TestPhase.results;
    });

    _fetchAiSuggestion(correct, total);
  }

  Future<void> _fetchAiSuggestion(int correct, int total) async {
    try {
      final chapter =
          _tabController.index == 0 ? _chapterName : 'Full Syllabus';
      final prompt =
          'The student scored $correct/$total on $chapter $_selectedSubject. '
          'What topics should they focus on? Give 3-4 specific suggestions in bullet points.';
      final response = await AiService.sendMessageToTutor(prompt);
      setState(() => _aiSuggestion = response);
    } catch (_) {
      setState(
          () => _aiSuggestion = 'Practice more to improve your understanding.');
    }
  }

  Future<void> _saveResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('self_test_results') ?? '[]';
      final List<dynamic> resultsList = json.decode(existing);

      final chapter =
          _tabController.index == 0 ? _chapterName : 'Full Syllabus';

      resultsList.add({
        'board': _selectedBoard,
        'class': _selectedClass,
        'subject': _selectedSubject,
        'chapter': chapter,
        'type': _tabController.index == 0 ? 'chapter' : 'syllabus',
        'score': _score,
        'total': _totalQuestions,
        'accuracy': _accuracy,
        'timeTaken': _timeTaken,
        'date': DateTime.now().toIso8601String(),
        'questions': _questionResults,
      });

      await prefs.setString('self_test_results', json.encode(resultsList));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Results saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  void _retakeTest() {
    _timer?.cancel();
    setState(() {
      _phase = TestPhase.setup;
      _questions = [];
      _userAnswers = [];
      _markedForReview = [];
      _questionResults = [];
      _aiSuggestion = '';
      _currentQuestionIndex = 0;
      _showNavigator = false;
    });
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? _buildLoading()
          : _phase == TestPhase.setup
              ? _buildSetup()
              : _phase == TestPhase.active
                  ? _buildActiveTest()
                  : _buildResults(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _accent),
          const SizedBox(height: 20),
          Text(_testStatusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ).animate().fadeIn(),
    );
  }

  // ─────────────────────────────────────────────
  // PHASE 1: SETUP
  // ─────────────────────────────────────────────
  Widget _buildSetup() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: _bgColor,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quiz, color: _accent),
              ),
              const SizedBox(width: 12),
              const Text('Test Yourself',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: _accent,
            labelColor: _accent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Chapter Test'),
              Tab(text: 'Syllabus Test'),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _tabController.index == 0
              ? _buildChapterTab()
              : _buildSyllabusTab(),
        ),
      ],
    );
  }

  Widget _buildChapterTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDropdown('Board', _boards, _selectedBoard, (v) {
            setState(() => _selectedBoard = v!);
          }),
          const SizedBox(height: 12),
          _buildClassSelector(),
          const SizedBox(height: 12),
          _buildDropdown('Subject', _subjects, _selectedSubject, (v) {
            setState(() => _selectedSubject = v!);
          }),
          const SizedBox(height: 16),
          _buildTextField('Chapter Name', Icons.book, (v) {
            _chapterName = v;
          }),
          const SizedBox(height: 16),
          _buildRadioGroup(
            'Number of Questions',
            ['5', '10', '15', '20'],
            _numQuestions.toString(),
            (v) => setState(() => _numQuestions = int.parse(v)),
          ),
          const SizedBox(height: 12),
          _buildRadioGroup(
            'Difficulty',
            ['Easy', 'Medium', 'Hard', 'Mixed'],
            _difficulty,
            (v) => setState(() => _difficulty = v),
          ),
          const SizedBox(height: 12),
          _buildRadioGroup(
            'Time Limit',
            ['5 min', '10 min', '15 min', '30 min', 'No Limit'],
            _timeLimit,
            (v) => setState(() => _timeLimit = v),
          ),
          const SizedBox(height: 30),
          _buildStartButton('Start Test 🚀', _startTest),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSyllabusTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDropdown('Board', _boards, _selectedBoard, (v) {
            setState(() => _selectedBoard = v!);
          }),
          const SizedBox(height: 12),
          _buildClassSelector(),
          const SizedBox(height: 12),
          _buildDropdown('Subject', _subjects, _selectedSubject, (v) {
            setState(() => _selectedSubject = v!);
          }),
          const SizedBox(height: 16),
          _buildRadioGroup(
            'Syllabus Scope',
            ['Full Syllabus', 'Selected Chapters'],
            _syllabusType == 'full' ? 'Full Syllabus' : 'Selected Chapters',
            (v) => setState(
                () => _syllabusType = v == 'Full Syllabus' ? 'full' : 'selected'),
          ),
          if (_syllabusType == 'selected') ...[
            const SizedBox(height: 12),
            _buildTextField('Chapters (comma separated)', Icons.book, (v) {
              _chapterName = v;
            }),
          ],
          const SizedBox(height: 16),
          _buildRadioGroup(
            'Number of Questions',
            ['10', '20', '30', '50'],
            _numQuestions.toString(),
            (v) => setState(() => _numQuestions = int.parse(v)),
          ),
          const SizedBox(height: 12),
          _buildRadioGroup(
            'Difficulty',
            ['Mixed'],
            'Mixed',
            (_) {},
          ),
          const SizedBox(height: 12),
          _buildRadioGroup(
            'Time Limit',
            ['30 min', '60 min', '90 min', '120 min'],
            _timeLimit,
            (v) => setState(() => _timeLimit = v),
          ),
          const SizedBox(height: 30),
          _buildStartButton('Start Full Test 🚀', _startTest),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        dropdownColor: _cardColor,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
        hint: Text(label,
            style: const TextStyle(color: Colors.white54)),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildClassSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('Class',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _classes.map((c) {
              final selected = c == _selectedClass;
              return GestureDetector(
                onTap: () => setState(() => _selectedClass = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? _accent : Colors.white24,
                    ),
                  ),
                  child: Text(
                    '$c',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, ValueChanged<String> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white38),
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String current,
      ValueChanged<String> onChanged) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final selected = opt == current;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _accent.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? _accent : Colors.white24,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: selected ? _accent : Colors.white70,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: _accent.withOpacity(0.4),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    ).animate().scale(delay: 100.ms);
  }

  // ─────────────────────────────────────────────
  // PHASE 2: ACTIVE TEST
  // ─────────────────────────────────────────────
  Widget _buildActiveTest() {
    final q = _questions[_currentQuestionIndex];
    final min = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;
    final progress = _totalTestSeconds > 0
        ? (_totalTestSeconds - _remainingSeconds) / _totalTestSeconds
        : (_currentQuestionIndex + 1) / _questions.length;

    return Stack(
      children: [
        Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
              color: _cardColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _remainingSeconds < 60
                              ? Colors.red.withOpacity(0.2)
                              : _accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer,
                                size: 16,
                                color: _remainingSeconds < 60
                                    ? Colors.red
                                    : _accent),
                            const SizedBox(width: 6),
                            Text(
                              '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: _remainingSeconds < 60
                                    ? Colors.red
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentQuestionIndex + 1} / ${_questions.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(_selectedSubject,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_accent),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),

            // Question area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question badge + text
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${_currentQuestionIndex + 1}',
                            style: const TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q['question'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Options
                    ...List.generate(4, (i) {
                      final labels = ['A', 'B', 'C', 'D'];
                      final selected = _userAnswers[_currentQuestionIndex] == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _userAnswers[_currentQuestionIndex] = i;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _accent.withOpacity(0.15)
                                  : _cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _accent : Colors.white12,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _accent
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    (q['options'] as List)[i],
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom navigation
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: _cardColor,
              child: SafeArea(
                child: Row(
                  children: [
                    _buildNavButton(
                      Icons.arrow_back_ios,
                      'Prev',
                      _currentQuestionIndex > 0
                          ? () => setState(() =>
                              _currentQuestionIndex--)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _buildNavButton(
                      Icons.flag,
                      'Mark',
                      () {
                        setState(() {
                          _markedForReview[_currentQuestionIndex] =
                              !_markedForReview[_currentQuestionIndex];
                        });
                      },
                      isActive: _markedForReview[_currentQuestionIndex],
                      activeColor: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildNavButton(
                      Icons.grid_view,
                      'Grid',
                      () => setState(
                          () => _showNavigator = !_showNavigator),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _currentQuestionIndex <
                                  _questions.length - 1
                              ? () => setState(() =>
                                  _currentQuestionIndex++)
                              : () {
                                  _showSubmitDialog();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _currentQuestionIndex ==
                                    _questions.length - 1
                                ? 'Submit'
                                : 'Next',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Question navigator overlay
        if (_showNavigator) _buildNavigatorOverlay(),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, String label, VoidCallback? onPressed,
      {bool isActive = false, Color? activeColor}) {
    final color = isActive ? (activeColor ?? _accent) : Colors.white54;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (activeColor ?? _accent).withOpacity(0.15)
              : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigatorOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showNavigator = false),
      child: Container(
        color: Colors.black87,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Question Navigator',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legendDot(Colors.green, 'Answered'),
                      const SizedBox(width: 12),
                      _legendDot(Colors.orange, 'Marked'),
                      const SizedBox(width: 12),
                      _legendDot(Colors.white24, 'Unanswered'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_questions.length, (i) {
                      Color bg;
                      if (_markedForReview[i]) {
                        bg = Colors.orange;
                      } else if (_userAnswers[i] != null) {
                        bg = Colors.green;
                      } else {
                        bg = Colors.white24;
                      }
                      final isCurrent = i == _currentQuestionIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentQuestionIndex = i;
                            _showNavigator = false;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: isCurrent
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: bg == Colors.white24
                                  ? Colors.white54
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _showNavigator = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  void _showSubmitDialog() {
    final unanswered =
        _userAnswers.where((a) => a == null).length;
    final marked =
        _markedForReview.where((m) => m).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Submit Test?',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answered: ${_questions.length - unanswered}/${_questions.length}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (unanswered > 0)
              Text('Unanswered: $unanswered',
                  style: const TextStyle(color: Colors.orange)),
            if (marked > 0)
              Text('Marked for review: $marked',
                  style: const TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue Test',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finishTest();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PHASE 3: RESULTS
  // ─────────────────────────────────────────────
  Widget _buildResults() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: _bgColor,
          title: const Text('Test Results',
              style: TextStyle(color: Colors.white)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildScoreCard(),
                const SizedBox(height: 16),
                _buildPerformanceSummary(),
                const SizedBox(height: 16),
                _buildAiSuggestions(),
                const SizedBox(height: 16),
                _buildTopicBreakdown(),
                const SizedBox(height: 16),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accent.withOpacity(0.3),
            _cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Grade badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Grade: $_grade',
                style: const TextStyle(
                    color: _accent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          // Circular progress
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: _accuracy / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _accuracy >= 70
                          ? Colors.green
                          : _accuracy >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_accuracy.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const Text('Accuracy',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('$_score / $_totalQuestions correct',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(_timeTaken,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPerformanceSummary() {
    int easy = 0, easyTotal = 0;
    int medium = 0, mediumTotal = 0;
    int hard = 0, hardTotal = 0;

    // Simple distribution based on position
    for (int i = 0; i < _questionResults.length; i++) {
      final r = _questionResults[i];
      if (i < (_questionResults.length * 0.4).ceil()) {
        easyTotal++;
        if (r['isCorrect']) easy++;
      } else if (i < (_questionResults.length * 0.75).ceil()) {
        mediumTotal++;
        if (r['isCorrect']) medium++;
      } else {
        hardTotal++;
        if (r['isCorrect']) hard++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _perfRow('Easy', easy, easyTotal, Colors.green),
          const SizedBox(height: 8),
          _perfRow('Medium', medium, mediumTotal, Colors.orange),
          const SizedBox(height: 8),
          _perfRow('Hard', hard, hardTotal, Colors.red),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _perfRow(String label, int correct, int total, Color color) {
    final pct = total > 0 ? correct / total : 0.0;
    return Row(
      children: [
        SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$correct/$total',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _buildAiSuggestions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _accent, size: 20),
              const SizedBox(width: 8),
              const Text('AI Suggestions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (_aiSuggestion.isEmpty)
            const Text('Loading suggestions...',
                style: TextStyle(color: Colors.white54))
          else
            Text(_aiSuggestion,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildTopicBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Question Breakdown',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...List.generate(_questionResults.length, (i) {
            final r = _questionResults[i];
            final isCorrect = r['isCorrect'] as bool;
            final userAns = r['userAnswer'] as int?;
            final correctAns = r['correct'] as int;
            final options = List<String>.from(r['options']);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withOpacity(0.08)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Q${i + 1}: ${r['question']}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (userAns != null)
                    Text(
                      'Your answer: ${options[userAns]}',
                      style: TextStyle(
                        color: isCorrect ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    )
                  else
                    const Text('Not answered',
                        style:
                            TextStyle(color: Colors.orange, fontSize: 12)),
                  if (!isCorrect)
                    Text(
                      'Correct: ${options[correctAns]}',
                      style: const TextStyle(
                          color: Colors.green, fontSize: 12),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saveResults,
            icon: const Icon(Icons.save),
            label: const Text('Save Results',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _retakeTest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}
