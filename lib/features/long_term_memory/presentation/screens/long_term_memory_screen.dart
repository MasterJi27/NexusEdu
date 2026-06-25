import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LongTermMemoryScreen extends StatefulWidget {
  const LongTermMemoryScreen({super.key});

  @override
  State<LongTermMemoryScreen> createState() => _LongTermMemoryScreenState();
}

class _LongTermMemoryScreenState extends State<LongTermMemoryScreen> {
  bool _isLoading = true;
  bool _isQuizzing = false;

  List<Map<String, dynamic>> _topics = [];
  int _currentQuizIndex = 0;
  List<Map<String, dynamic>> _quizQuestions = [];
  int? _selectedAnswer;
  bool _quizComplete = false;
  List<Map<String, dynamic>> _quizResults = [];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('long_term_memory');
    if (saved != null) {
      final decoded = json.decode(saved) as Map<String, dynamic>;
      _topics = (decoded['topics'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    }
    if (_topics.isEmpty) {
      _generateSyntheticTopics();
    }
    setState(() => _isLoading = false);
  }

  void _generateSyntheticTopics() {
    final subjects = ['Physics', 'Chemistry', 'Maths', 'Biology'];
    final topics = {
      'Physics': ['Newton\'s Laws', 'Ohm\'s Law', 'Conservation of Energy', 'Wave Motion', 'Electromagnetic Induction'],
      'Chemistry': ['Periodic Table', 'Chemical Bonding', 'Organic Reactions', 'Acid-Base Equilibria', 'Electrochemistry'],
      'Maths': ['Derivatives', 'Integration', 'Matrix Operations', 'Probability Theorems', 'Trigonometric Identities'],
      'Biology': ['Cell Division', 'DNA Replication', 'Photosynthesis', 'Human Digestive System', 'Evolution'],
    };

    for (final subject in subjects) {
      for (final topic in topics[subject]!) {
        final daysAgo = Random().nextInt(30) + 1;
        final retention = LocalComputation.forgettingCurve(5.0, daysAgo.toDouble()) * 100;
        _topics.add({
          'subject': subject,
          'topic': topic,
          'lastStudied': DateTime.now().subtract(Duration(days: daysAgo)).toIso8601String(),
          'retention': retention,
          'reviewCount': Random().nextInt(5),
        });
      }
    }
  }

  Future<void> _startQuiz() async {
    setState(() {
      _isQuizzing = true;
      _quizComplete = false;
      _currentQuizIndex = 0;
      _selectedAnswer = null;
      _quizResults = [];
    });

    final oldTopics = _topics.where((t) {
      final lastStudied = DateTime.tryParse(t['lastStudied'] ?? '');
      return lastStudied != null && DateTime.now().difference(lastStudied).inDays > 5;
    }).toList();

    if (oldTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No old topics to test. Study more topics first!')),
      );
      setState(() => _isQuizzing = false);
      return;
    }

    final selected = (oldTopics..shuffle()).take(min(3, oldTopics.length)).toList();

    try {
      final response = await AiAgentService.callAgent('custom', {
        'prompt': 'Generate 3 multiple choice questions for these topics:\n'
            '${selected.map((t) => "${t['topic']} (${t['subject']})").join(", ")}\n'
            'Format each as: QUESTION: ...\nOPTIONS: A) ... B) ... C) ... D) ...\nANSWER: A/B/C/D',
      });

      _quizQuestions = [];
      final questionBlocks = response.split(RegExp(r'QUESTION:'));
      for (final block in questionBlocks) {
        if (block.trim().isEmpty) continue;
        final qMatch = RegExp(r'(.+?)(?:OPTIONS:)').firstMatch(block);
        final oMatch = RegExp(r'OPTIONS:\s*(.+)').firstMatch(block);
        final aMatch = RegExp(r'ANSWER:\s*([A-D])').firstMatch(block);
        if (qMatch != null && oMatch != null && aMatch != null) {
          final optionsStr = oMatch.group(1)!;
          final options = RegExp(r'[A-D]\)\s*([^,]+)').allMatches(optionsStr).map((m) => m.group(1)!.trim()).toList();
          if (options.length >= 4) {
            _quizQuestions.add({
              'question': qMatch.group(1)!.trim(),
              'options': options,
              'correct': aMatch.group(1)!.codeUnitAt(0) - 'A'.codeUnitAt(0),
              'topic': selected[_quizQuestions.length % selected.length]['topic'],
            });
          }
        }
      }
    } catch (_) {
      _quizQuestions = selected.take(3).map((t) => {
        'question': 'What is a key concept in ${t['topic']}?',
        'options': ['Concept A', 'Concept B', 'Concept C', 'Concept D'],
        'correct': Random().nextInt(4),
        'topic': t['topic'],
      }).toList();
    }

    setState(() {});
  }

  void _answerQuestion(int answer) {
    setState(() {
      _selectedAnswer = answer;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswer == null) return;
    final correct = _quizQuestions[_currentQuizIndex]['correct'] == _selectedAnswer;
    _quizResults.add({
      'question': _quizQuestions[_currentQuizIndex]['question'],
      'correct': correct,
      'topic': _quizQuestions[_currentQuizIndex]['topic'],
    });

    if (_currentQuizIndex < _quizQuestions.length - 1) {
      setState(() {
        _currentQuizIndex++;
        _selectedAnswer = null;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    for (final result in _quizResults) {
      final topicIdx = _topics.indexWhere((t) => t['topic'] == result['topic']);
      if (topicIdx >= 0) {
        _topics[topicIdx]['retention'] = result['correct'] ? 95.0 : 30.0;
        _topics[topicIdx]['lastStudied'] = DateTime.now().toIso8601String();
        _topics[topicIdx]['reviewCount'] = (_topics[topicIdx]['reviewCount'] ?? 0) + 1;
      }
    }

    setState(() {
      _quizComplete = true;
    });
    _saveTopics();
  }

  Future<void> _saveTopics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('long_term_memory', json.encode({'topics': _topics}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Long-Term Memory Agent', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : _isQuizzing
              ? _buildQuizView()
              : _buildTopicList(),
    );
  }

  Widget _buildTopicList() {
    final sortedTopics = List<Map<String, dynamic>>.from(_topics)
      ..sort((a, b) => (a['retention'] as double).compareTo(b['retention'] as double));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTestButton(),
          const SizedBox(height: 20),
          const Text('Topics Studied', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('${_topics.length} topics tracked', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12)),
          const SizedBox(height: 12),
          ...sortedTopics.map((t) => _buildTopicCard(t)),
          const SizedBox(height: 20),
          _buildSpacedRepetitionSchedule(),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _startQuiz,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.quiz),
        label: const Text('Test Memory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ).animate().fade();
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final retention = topic['retention'] as double;
    final lastStudied = DateTime.tryParse(topic['lastStudied'] ?? '') ?? DateTime.now();
    final daysAgo = DateTime.now().difference(lastStudied).inDays;
    final color = retention >= 70 ? Colors.greenAccent : retention >= 40 ? Colors.amberAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic['topic'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${topic['subject']} • $daysAgo days ago',
                    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
              ],
            ),
          ),
          Column(
            children: [
              Text('${retention.toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('retention', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpacedRepetitionSchedule() {
    final dueTopics = _topics.where((t) {
      final retention = t['retention'] as double;
      return retention < 70;
    }).take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spaced Repetition Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (dueTopics.isEmpty)
            Text('All topics have good retention!', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13))
          else
            ...dueTopics.map((t) {
              final retention = t['retention'] as double;
              final urgency = retention < 30 ? 'Review NOW' : retention < 50 ? 'Review today' : 'Review this week';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.deepPurpleAccent.withAlpha(200), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${t['topic']} — $urgency',
                          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
                    ),
                    Text('${retention.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: retention < 30 ? Colors.redAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                  ],
                ),
              );
            }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildQuizView() {
    if (_quizComplete) return _buildQuizResults();
    if (_quizQuestions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    final q = _quizQuestions[_currentQuizIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_currentQuizIndex + 1}/${_quizQuestions.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              OutlinedButton(
                onPressed: () => setState(() {
                  _isQuizzing = false;
                  _quizComplete = false;
                }),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withAlpha(30))),
                child: Text('Exit', style: TextStyle(color: Colors.white.withAlpha(150))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuizIndex + 1) / _quizQuestions.length,
            backgroundColor: Colors.white.withAlpha(15),
            valueColor: const AlwaysStoppedAnimation(Colors.deepPurpleAccent),
          ),
          const SizedBox(height: 20),
          Text(q['topic'] ?? '', style: TextStyle(color: Colors.deepPurpleAccent.withAlpha(200), fontSize: 12)),
          const SizedBox(height: 8),
          Text(q['question'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          ...List.generate(4, (i) {
            final isSelected = _selectedAnswer == i;
            return GestureDetector(
              onTap: () => _answerQuestion(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepPurpleAccent.withAlpha(40) : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(String.fromCharCode(65 + i),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text((q['options'] as List)[i], style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedAnswer == null ? null : _nextQuestion,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _currentQuizIndex < _quizQuestions.length - 1 ? 'Next' : 'Finish',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildQuizResults() {
    final correctCount = _quizResults.where((r) => r['correct'] == true).length;
    final score = (correctCount / _quizResults.length * 100).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text('Quiz Complete!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 16),
                Text('$score%', style: TextStyle(
                  color: score >= 70 ? Colors.greenAccent : score >= 50 ? Colors.amberAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold, fontSize: 40,
                )),
                Text('$correctCount/${_quizResults.length} correct', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._quizResults.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(r['correct'] ? Icons.check_circle : Icons.cancel,
                        color: r['correct'] ? Colors.greenAccent : Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['question'] ?? '', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                          Text(r['topic'] ?? '', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() {
                _isQuizzing = false;
                _quizComplete = false;
              }),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Topics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }
}
