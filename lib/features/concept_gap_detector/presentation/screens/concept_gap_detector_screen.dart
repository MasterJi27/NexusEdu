import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/question_bank_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConceptGapDetectorScreen extends StatefulWidget {
  const ConceptGapDetectorScreen({super.key});

  @override
  State<ConceptGapDetectorScreen> createState() =>
      _ConceptGapDetectorScreenState();
}

class _ConceptGapDetectorScreenState extends State<ConceptGapDetectorScreen> {
  String _selectedSubject = 'physics';
  bool _isLoading = false;
  bool _diagnosticStarted = false;
  bool _isAnalyzing = false;
  bool _hasResult = false;

  int _currentQ = 0;
  int _correctCount = 0;
  int? _selectedAnswer;
  bool _answered = false;
  List<Map<String, dynamic>> _diagnosticQuestions = [];

  List<Map<String, dynamic>> _missingPrereqs = [];
  List<Map<String, dynamic>> _learningPath = [];
  String _gapSeverity = 'green';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('concept_gaps') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'concept_gaps',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  void _startDiagnostic() {
    final questions =
        QuestionBankLocal.getQuestions(_selectedSubject, count: 5, difficulty: 2);
    setState(() {
      _diagnosticStarted = true;
      _hasResult = false;
      _currentQ = 0;
      _correctCount = 0;
      _selectedAnswer = null;
      _answered = false;
      _diagnosticQuestions = questions;
    });
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final correct = _diagnosticQuestions[_currentQ]['correct'] as int;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == correct) _correctCount++;
    });
  }

  void _nextQuestion() {
    if (_currentQ < _diagnosticQuestions.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _analyzeGaps();
    }
  }

  Future<void> _analyzeGaps() async {
    setState(() => _isAnalyzing = true);

    final wrongTopics = <String>[];
    for (final q in _diagnosticQuestions) {
      q['correct'] as int;
      final idx = _diagnosticQuestions.indexOf(q);
      if (idx < _correctCount) continue;
      wrongTopics.add(q['chapter'] ?? 'Unknown');
    }

    final prompt =
        'Student took a $_selectedSubject diagnostic test and got $_correctCount/5 correct.\n'
        'Wrong topics: ${wrongTopics.isEmpty ? "None" : wrongTopics.join(", ")}\n\n'
        'Analyze concept gaps:\n'
        'MISSING_PREREQS: list 2-3 prerequisite concepts (name|description) separated by ;\n'
        'LEARNING_PATH: list 3-5 topics in order to study (topic|why) separated by ;\n'
        'SEVERITY: red (critical gaps) or yellow (moderate) or green (minor)';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'MISSING_PREREQS: Basic Concepts|Review fundamentals;Practice Problems|Solve more questions\n'
          'LEARNING_PATH: Fundamentals|Build strong base;$_selectedSubject Basics|Core concepts;Practice|Apply knowledge\n'
          'SEVERITY: ${_correctCount >= 4 ? "green" : _correctCount >= 2 ? "yellow" : "red"}';
    }

    final prereqs = <Map<String, dynamic>>[];
    final prereqMatch = RegExp(r'MISSING_PREREQS:\s*(.+?)(?=LEARNING_PATH:|$)', dotAll: true)
        .firstMatch(response);
    if (prereqMatch != null) {
      final items = prereqMatch.group(1)!.split(';');
      for (final item in items) {
        final parts = item.split('|');
        if (parts.length >= 2) {
          prereqs.add({
            'name': parts[0].trim(),
            'description': parts[1].trim(),
          });
        }
      }
    }

    final path = <Map<String, dynamic>>[];
    final pathMatch = RegExp(r'LEARNING_PATH:\s*(.+?)(?=SEVERITY:|$)', dotAll: true)
        .firstMatch(response);
    if (pathMatch != null) {
      final items = pathMatch.group(1)!.split(';');
      for (final item in items) {
        final parts = item.split('|');
        if (parts.length >= 2) {
          path.add({
            'topic': parts[0].trim(),
            'reason': parts[1].trim(),
          });
        }
      }
    }

    final severityMatch = RegExp(r'SEVERITY:\s*(\w+)').firstMatch(response);
    final severity = severityMatch?.group(1)?.trim() ?? 'yellow';

    final result = {
      'subject': _selectedSubject,
      'score': _correctCount,
      'total': _diagnosticQuestions.length,
      'missingPrereqs': prereqs,
      'learningPath': path,
      'severity': severity,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _missingPrereqs = prereqs;
      _learningPath = path;
      _gapSeverity = severity;
      _isAnalyzing = false;
      _hasResult = true;
    });

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'red':
        return Colors.redAccent;
      case 'yellow':
        return Colors.amberAccent;
      case 'green':
        return Colors.greenAccent;
      default:
        return Colors.amberAccent;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'red':
        return 'Critical Gaps';
      case 'yellow':
        return 'Moderate Gaps';
      case 'green':
        return 'Minor Gaps';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Concept Gap Detector',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _diagnosticStarted
          ? _hasResult
              ? _buildResultView()
              : _buildDiagnosticView()
          : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubjectSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startDiagnostic,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Start Diagnostic',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      (val) => setState(() => _selectedSubject = val!),
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

  Widget _buildDiagnosticView() {
    if (_diagnosticQuestions.isEmpty) {
      return const Center(
        child: Text('No questions available',
            style: TextStyle(color: Colors.white54)),
      );
    }
    final q = _diagnosticQuestions[_currentQ];
    final options = List<String>.from(q['options'] ?? []);
    final progress = (_currentQ + 1) / _diagnosticQuestions.length;

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
                    'Q${_currentQ + 1}/${_diagnosticQuestions.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  Text(
                    'Correct: $_correctCount',
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
                      onPressed: _isAnalyzing ? null : _nextQuestion,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAnalyzing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : Text(
                              _currentQ < _diagnosticQuestions.length - 1
                                  ? 'Next Question'
                                  : 'Analyze Gaps',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildResultView() {
    final severityColor = _severityColor(_gapSeverity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: severityColor.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: severityColor.withAlpha(60)),
            ),
            child: Column(
              children: [
                Icon(
                  _gapSeverity == 'red'
                      ? Icons.error_outline
                      : _gapSeverity == 'yellow'
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                  color: severityColor,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _severityLabel(_gapSeverity),
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score: $_correctCount/5',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ).animate().fade(),
          if (_missingPrereqs.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Missing Prerequisites',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ..._missingPrereqs.map((prereq) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.menu_book,
                          color: Colors.deepPurpleAccent.withAlpha(200),
                          size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prereq['name'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              prereq['description'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (_learningPath.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Recommended Learning Path',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ..._learningPath.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['topic'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            item['reason'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(150),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade(delay: Duration(milliseconds: 100 * idx));
            }),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _diagnosticStarted = false;
                  _hasResult = false;
                  _diagnosticQuestions.clear();
                });
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start New Diagnostic',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final sev = r['severity'] ?? 'yellow';
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
              color: _severityColor(sev).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.analytics,
                color: _severityColor(sev), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['subject']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']}/${r['total']} • ${_severityLabel(sev)}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _severityColor(sev).withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sev.toUpperCase(),
              style: TextStyle(
                color: _severityColor(sev),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
