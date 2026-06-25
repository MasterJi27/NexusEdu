import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupStudyModScreen extends StatefulWidget {
  const GroupStudyModScreen({super.key});

  @override
  State<GroupStudyModScreen> createState() => _GroupStudyModScreenState();
}

class _GroupStudyModScreenState extends State<GroupStudyModScreen> {
  String _selectedTopic = 'Physics - Mechanics';
  bool _isLoading = false;
  bool _sessionActive = false;
  bool _quizMode = false;
  bool _isProcessing = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _quizQuestions = [];
  int _currentQuizIndex = 0;
  String _sessionSummary = '';
  List<Map<String, dynamic>> _pastSessions = [];

  final List<String> _topics = [
    'Physics - Mechanics',
    'Physics - Electromagnetism',
    'Chemistry - Organic',
    'Chemistry - Inorganic',
    'Biology - Genetics',
    'Biology - Ecology',
    'Mathematics - Calculus',
    'Mathematics - Algebra',
    'History - Modern India',
    'Geography - Climatology',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('group_study_sessions') ?? [];
    setState(() {
      _pastSessions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getStringList('group_study_sessions') ?? [];
    sessions.add(json.encode({
      'topic': _selectedTopic,
      'messages': _messages,
      'summary': _sessionSummary,
      'quizMode': _quizMode,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (sessions.length > 20) sessions.removeAt(0);
    await prefs.setStringList('group_study_sessions', sessions);
    _loadSessions();
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _messages = [];
      _quizMode = false;
      _quizQuestions = [];
      _currentQuizIndex = 0;
    });

    final prompt =
        'You are a group study moderator for $_selectedTopic.\n'
        'Introduce the topic, present 3 key concepts, then ask a discussion '
        'question to the group. Be engaging and educational.';

    try {
      final response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
      _messages.add({'role': 'moderator', 'text': response});
    } catch (_) {
      _messages.add({
        'role': 'moderator',
        'text': 'Welcome to our $_selectedTopic study session! '
            'Let\'s explore the key concepts together.',
      });
    }

    setState(() {
      _isLoading = false;
      _sessionActive = true;
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _messages.add({'role': 'group', 'text': text});
    });
    _scrollToBottom();
    _messageController.clear();

    final chatHistory = _messages
        .map((m) => '${m['role'] == 'moderator' ? 'Moderator' : 'Group'}: ${m['text']}')
        .join('\n');

    final prompt =
        'You are a group study moderator for $_selectedTopic.\n'
        'Discussion so far:\n$chatHistory\n\n'
        'Respond as the moderator. Discuss the point, ask follow-up questions, '
        'and encourage deeper thinking.';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'Great point! Let\'s think about this more deeply.';
    }

    setState(() {
      _messages.add({'role': 'moderator', 'text': response});
      _isProcessing = false;
    });
    _scrollToBottom();
  }

  Future<void> _startQuiz() async {
    setState(() {
      _isLoading = true;
      _quizMode = true;
      _quizQuestions = [];
      _currentQuizIndex = 0;
    });

    try {
      final response = await AiAgentService.callAgent(
        'quiz_generator',
        {'topic': _selectedTopic, 'count': 5, 'difficulty': 3},
      );
      _parseQuizQuestions(response);
    } catch (_) {
      _quizQuestions = [
        {'q': 'What is the key concept of $_selectedTopic?', 'a': 'Core principle'},
        {'q': 'Name one important formula.', 'a': 'F = ma'},
      ];
    }

    setState(() {
      _isLoading = false;
      if (_quizQuestions.isNotEmpty) {
        _messages.add({
          'role': 'moderator',
          'text': 'Quiz Time! Question 1:\n${_quizQuestions[0]['q']}',
        });
      }
    });
    _scrollToBottom();
  }

  void _parseQuizQuestions(String response) {
    final qMatches = RegExp(r'Q:\s*(.+?)(?=A:|$)', dotAll: true)
        .allMatches(response);
    final aMatches = RegExp(r'A:\s*(.+?)(?=Q:|$)', dotAll: true)
        .allMatches(response);

    final questions = qMatches.map((m) => m.group(1)!.trim()).toList();
    final answers = aMatches.map((m) => m.group(1)!.trim()).toList();

    for (var i = 0; i < questions.length && i < answers.length; i++) {
      _quizQuestions.add({'q': questions[i], 'a': answers[i]});
    }
  }

  void _nextQuizQuestion() {
    _currentQuizIndex++;
    if (_currentQuizIndex < _quizQuestions.length) {
      setState(() {
        _messages.add({
          'role': 'moderator',
          'text':
              'Question ${_currentQuizIndex + 1}:\n${_quizQuestions[_currentQuizIndex]['q']}',
        });
      });
    } else {
      _endQuiz();
    }
    _scrollToBottom();
  }

  Future<void> _endQuiz() async {
    setState(() => _isLoading = true);

    final prompt =
        'The quiz on $_selectedTopic has ended. Provide a brief session summary '
        'covering what was discussed and studied. Highlight strengths and areas to review.';

    try {
      _sessionSummary = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      _sessionSummary = 'Good session! Keep reviewing $_selectedTopic.';
    }

    setState(() {
      _isLoading = false;
      _messages.add({
        'role': 'moderator',
        'text': 'Session Complete!\n$_sessionSummary',
      });
    });
    _scrollToBottom();
    _saveSession();
  }

  Future<void> _endSession() async {
    setState(() => _isLoading = true);

    final prompt =
        'Summarize this $_selectedTopic group study session.\n'
        'Key points discussed:\n${_messages.where((m) => m['role'] == 'group').map((m) => '- ${m['text']}').join('\n')}\n'
        'Provide a concise summary with action items.';

    try {
      _sessionSummary = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      _sessionSummary = 'Study session completed. Review the key concepts discussed.';
    }

    setState(() {
      _isLoading = false;
      _messages.add({
        'role': 'moderator',
        'text': 'Session Complete!\n$_sessionSummary',
      });
    });
    _scrollToBottom();
    _saveSession();
  }

  void _resetSession() {
    setState(() {
      _sessionActive = false;
      _quizMode = false;
      _messages = [];
      _quizQuestions = [];
      _currentQuizIndex = 0;
      _sessionSummary = '';
    });
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
          'Group Study Moderator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_sessionActive)
            IconButton(
              onPressed: _resetSession,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _sessionActive ? _buildSessionView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.groups,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Study Together',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI-moderated group study sessions with quizzes.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildTopicSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startSession,
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isLoading ? 'Starting...' : 'Start Session',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastSessions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastSessions.length.clamp(0, 5), (i) {
              final s = _pastSessions[i];
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
                      child: const Icon(Icons.groups,
                          color: Colors.deepPurpleAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['topic'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(s['messages'] as List?)?.length ?? 0} messages',
                            style: TextStyle(
                              color: Colors.white.withAlpha(120),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTopicSelector() {
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
            'Topic',
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
            children: _topics.map((t) {
              final isSelected = t == _selectedTopic;
              return GestureDetector(
                onTap: () => setState(() => _selectedTopic = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
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
                    t,
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

  Widget _buildSessionView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Row(
            children: [
              Icon(
                _quizMode ? Icons.quiz : Icons.groups,
                color: Colors.deepPurpleAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedTopic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!_quizMode)
                GestureDetector(
                  onTap: _isLoading ? null : _startQuiz,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Quiz Mode',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              if (_quizMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Q${_currentQuizIndex + 1}/${_quizQuestions.length}',
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
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
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _buildMessageBubble(_messages[index]);
            },
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ),
        if (_quizMode && _currentQuizIndex < _quizQuestions.length)
          _buildQuizActions()
        else
          _buildInputArea(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isModerator = msg['role'] == 'moderator';
    return Align(
      alignment: isModerator ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isModerator
              ? const Color(0xFF1E1E1E)
              : Colors.deepPurpleAccent.withAlpha(40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isModerator
                ? Colors.amberAccent.withAlpha(40)
                : Colors.deepPurpleAccent.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                isModerator ? 'Moderator' : 'Group',
                style: TextStyle(
                  color: isModerator
                      ? Colors.amberAccent
                      : Colors.deepPurpleAccent,
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

  Widget _buildQuizActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your answer...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _submitQuizAnswer(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _messageController.text.trim().isEmpty
                  ? null
                  : _submitQuizAnswer,
              icon: const Icon(Icons.check_circle,
                  color: Colors.tealAccent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuizAnswer() async {
    final answer = _messageController.text.trim();
    if (answer.isEmpty) return;

    setState(() {
      _messages.add({'role': 'group', 'text': answer});
    });
    _messageController.clear();
    _scrollToBottom();

    final correctAnswer = _quizQuestions[_currentQuizIndex]['a'] ?? '';
    final prompt =
        'Quiz answer received.\nQuestion: ${_quizQuestions[_currentQuizIndex]['q']}\n'
        'Student answer: "$answer"\nCorrect answer: "$correctAnswer"\n'
        'Provide brief feedback (correct/incorrect) and explanation.';

    String feedback;
    try {
      feedback = await AiAgentService.callAgent('custom', {'prompt': prompt});
    } catch (_) {
      feedback = answer.toLowerCase().contains(correctAnswer.toLowerCase())
          ? 'Correct!'
          : 'The correct answer is: $correctAnswer';
    }

    setState(() {
      _messages.add({'role': 'moderator', 'text': feedback});
    });
    _scrollToBottom();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuizQuestion();
    });
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isProcessing || _messageController.text.trim().isEmpty
                  ? null
                  : _sendMessage,
              icon: Icon(
                Icons.send,
                color: _isProcessing || _messageController.text.trim().isEmpty
                    ? Colors.white24
                    : Colors.deepPurpleAccent,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _isLoading ? null : _endSession,
              icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
