import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockInterviewScreen extends StatefulWidget {
  const MockInterviewScreen({super.key});

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  String _selectedField = 'Engineering';
  String _selectedRound = 'Technical';
  bool _isLoading = false;
  bool _interviewStarted = false;
  bool _isProcessing = false;

  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _conversation = [];
  int _currentQuestionIndex = 0;
  int _totalQuestions = 5;
  int _totalScore = 0;
  List<int> _questionScores = [];
  String _currentQuestion = '';
  bool _interviewFinished = false;
  String _finalEvaluation = '';
  List<Map<String, dynamic>> _results = [];

  final Map<String, List<String>> _roundsByField = {
    'Engineering': ['Technical', 'HR', 'GD'],
    'Medical': ['Technical', 'HR', 'Ethics'],
    'MBA': ['Case Study', 'HR', 'GD'],
    'General': ['Technical', 'HR', 'Aptitude'],
  };

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('mock_interviews') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'mock_interviews',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _startInterview() async {
    setState(() {
      _isLoading = true;
      _conversation = [];
      _currentQuestionIndex = 0;
      _totalScore = 0;
      _questionScores = [];
      _interviewFinished = false;
      _finalEvaluation = '';
    });

    final prompt =
        'You are an interviewer for a $_selectedField $_selectedRound interview. '
        'Ask the first interview question. Return only the question text.';

    try {
      _currentQuestion = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      _currentQuestion = 'Tell me about yourself and why you are interested in $_selectedField.';
    }

    setState(() {
      _isLoading = false;
      _interviewStarted = true;
      _conversation.add({
        'role': 'interviewer',
        'text': _currentQuestion,
      });
    });
    _scrollToBottom();
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _conversation.add({'role': 'candidate', 'text': answer});
    });
    _scrollToBottom();
    _answerController.clear();

    final prompt =
        'Evaluate this $_selectedField $_selectedRound interview answer:\n'
        'Question: "$_currentQuestion"\n'
        'Answer: "$answer"\n\n'
        'Score from 1-10, brief feedback, then the next question.\n'
        'Format: SCORE: X\nFEEDBACK: ...\nNEXT: ...';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'SCORE: 5\nFEEDBACK: Decent answer, could be more detailed.\n'
          'NEXT: What are your strengths and weaknesses?';
    }

    int score = 5;
    String feedback = '';
    String nextQuestion = '';

    final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(response);
    if (scoreMatch != null) score = int.tryParse(scoreMatch.group(1)!) ?? 5;
    final feedbackMatch =
        RegExp(r'FEEDBACK:\s*(.+?)(?=NEXT:|$)', dotAll: true).firstMatch(response);
    if (feedbackMatch != null) feedback = feedbackMatch.group(1)!.trim();
    final nextMatch = RegExp(r'NEXT:\s*(.+)').firstMatch(response);
    if (nextMatch != null) nextQuestion = nextMatch.group(1)!.trim();

    setState(() {
      _totalScore += score;
      _questionScores.add(score);
      _conversation.add({
        'role': 'feedback',
        'text': 'Score: $score/10\n$feedback',
      });
      _currentQuestionIndex++;
    });
    _scrollToBottom();

    if (_currentQuestionIndex < _totalQuestions && nextQuestion.isNotEmpty) {
      setState(() {
        _currentQuestion = nextQuestion;
        _conversation.add({'role': 'interviewer', 'text': nextQuestion});
        _isProcessing = false;
      });
      _scrollToBottom();
    } else {
      _finishInterview();
    }
  }

  Future<void> _finishInterview() async {
    final avgScore = _questionScores.isNotEmpty
        ? (_totalScore / _questionScores.length).toStringAsFixed(1)
        : '0';

    final prompt =
        'Give a final evaluation for a $_selectedField $_selectedRound mock interview.\n'
        'Scores given: ${_questionScores.join(", ")}\n'
        'Average: $avgScore/10\n'
        'Provide a brief overall evaluation in 2-3 sentences.';

    try {
      _finalEvaluation = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      _finalEvaluation =
          'Overall performance: Average. Keep practicing to improve your responses.';
    }

    final result = {
      'field': _selectedField,
      'round': _selectedRound,
      'totalScore': _totalScore,
      'maxScore': _totalQuestions * 10,
      'questionScores': _questionScores,
      'evaluation': _finalEvaluation,
      'questionsAsked': _currentQuestionIndex,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isProcessing = false;
      _interviewFinished = true;
      _conversation.add({
        'role': 'system',
        'text': 'Interview Complete! Final Evaluation:\n$_finalEvaluation',
      });
    });
    _scrollToBottom();

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Mock Interview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _interviewStarted ? _buildInterviewView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldSelector(),
          const SizedBox(height: 16),
          _buildRoundSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startInterview,
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
                _isLoading ? 'Preparing...' : 'Start Interview',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Interviews',
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

  Widget _buildFieldSelector() {
    return _buildSelectorRow(
      'Field',
      ['Engineering', 'Medical', 'MBA', 'General'],
      _selectedField,
      (val) => setState(() {
        _selectedField = val!;
        _selectedRound = _roundsByField[_selectedField]!.first;
      }),
    );
  }

  Widget _buildRoundSelector() {
    final rounds = _roundsByField[_selectedField] ?? ['Technical'];
    return _buildSelectorRow(
      'Round',
      rounds,
      _selectedRound,
      (val) => setState(() => _selectedRound = val!),
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

  Widget _buildInterviewView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _interviewFinished
                    ? 'Complete'
                    : 'Q${_currentQuestionIndex + 1}/${_totalQuestions + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Score: $_totalScore',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _conversation.length,
            itemBuilder: (context, index) {
              return _buildChatBubble(_conversation[index]);
            },
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ),
        if (!_interviewFinished)
          _buildInputArea(),
      ],
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isInterviewer = msg['role'] == 'interviewer';
    final isCandidate = msg['role'] == 'candidate';
    final isFeedback = msg['role'] == 'feedback';
    final isSystem = msg['role'] == 'system';

    return Align(
      alignment: isCandidate ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isCandidate
              ? Colors.deepPurpleAccent.withAlpha(40)
              : isFeedback
                  ? Colors.amberAccent.withAlpha(20)
                  : isSystem
                      ? Colors.tealAccent.withAlpha(20)
                      : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCandidate
                ? Colors.deepPurpleAccent.withAlpha(60)
                : isFeedback
                    ? Colors.amberAccent.withAlpha(40)
                    : isSystem
                        ? Colors.tealAccent.withAlpha(40)
                        : Colors.white.withAlpha(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                isInterviewer
                    ? 'Interviewer'
                    : isCandidate
                        ? 'You'
                        : isFeedback
                            ? 'Feedback'
                            : 'System',
                style: TextStyle(
                  color: isCandidate
                      ? Colors.deepPurpleAccent
                      : isFeedback
                          ? Colors.amberAccent
                          : isSystem
                              ? Colors.tealAccent
                              : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              msg['text'] ?? '',
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ).animate().fade(),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _answerController,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isProcessing || _answerController.text.trim().isEmpty
                ? null
                : _submitAnswer,
            icon: Icon(
              Icons.send,
              color: _isProcessing || _answerController.text.trim().isEmpty
                  ? Colors.white24
                  : Colors.deepPurpleAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final pct = r['maxScore'] > 0
        ? ((r['totalScore'] as int) / (r['maxScore'] as int) * 100).round()
        : 0;
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
            child: const Icon(Icons.work,
                color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['field']} - ${r['round']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['totalScore']}/${r['maxScore']} • $pct%',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              color: pct >= 70
                  ? Colors.greenAccent
                  : pct >= 50
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
