import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceVivaScreen extends StatefulWidget {
  const VoiceVivaScreen({super.key});

  @override
  State<VoiceVivaScreen> createState() => _VoiceVivaScreenState();
}

class _VoiceVivaScreenState extends State<VoiceVivaScreen> {
  String _selectedSubject = 'physics';
  String _selectedChapter = 'All';
  bool _isLoading = false;
  bool _vivaStarted = false;
  bool _isListening = false;
  bool _isProcessing = false;

  late stt.SpeechToText _speech;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _conversation = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _totalQuestions = 5;
  String _currentQuestion = '';
  List<Map<String, dynamic>> _results = [];

  final Map<String, List<String>> _chaptersBySubject = {
    'physics': [
      'All',
      'Motion',
      'Force and Laws of Motion',
      'Work Energy and Power',
      'Light - Reflection and Refraction',
    ],
    'chemistry': [
      'All',
      'Acids Bases and Salts',
      'Chemical Bonding',
      'Structure of the Atom',
    ],
    'maths': [
      'All',
      'Trigonometry',
      'Quadratic Equations',
      'Calculus',
    ],
    'biology': [
      'All',
      'Cell Biology',
      'Life Processes',
      'Heredity and Evolution',
    ],
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadResults();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('viva_sessions') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'viva_sessions',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _startViva() async {
    setState(() {
      _isLoading = true;
      _conversation = [];
      _currentQuestionIndex = 0;
      _score = 0;
    });

    final chapter = _selectedChapter == 'All' ? '' : ' in $_selectedChapter';
    final prompt = 'Generate the first viva question for $_selectedSubject$chapter. '
        'Return only the question text, nothing else.';

    try {
      _currentQuestion = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      _currentQuestion =
          'Explain the basic concepts of $_selectedSubject$chapter.';
    }

    setState(() {
      _isLoading = false;
      _vivaStarted = true;
      _conversation.add({
        'role': 'ai',
        'text': _currentQuestion,
      });
    });
    _scrollToBottom();
  }

  Future<void> _evaluateAndFollowUp(String userAnswer) async {
    setState(() {
      _isProcessing = true;
      _conversation.add({
        'role': 'user',
        'text': userAnswer,
      });
    });
    _scrollToBottom();

    final prompt =
        'Evaluate this viva answer for $_selectedSubject: "$userAnswer"\n'
        'Question asked: "$_currentQuestion"\n'
        'Provide a score from 0-10 and brief feedback. '
        'Then ask a follow-up question. '
        'Format: SCORE: X/10\nFEEDBACK: ...\nFOLLOWUP: ...';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'SCORE: 5/10\nFEEDBACK: Answer needs more detail.\n'
          'FOLLOWUP: Can you elaborate further?';
    }

    int questionScore = 5;
    String feedback = '';
    String followUp = '';

    final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(response);
    if (scoreMatch != null) {
      questionScore = int.tryParse(scoreMatch.group(1)!) ?? 5;
    }
    final feedbackMatch =
        RegExp(r'FEEDBACK:\s*(.+?)(?=FOLLOWUP:|$)', dotAll: true)
            .firstMatch(response);
    if (feedbackMatch != null) {
      feedback = feedbackMatch.group(1)!.trim();
    }
    final followUpMatch = RegExp(r'FOLLOWUP:\s*(.+)').firstMatch(response);
    if (followUpMatch != null) {
      followUp = followUpMatch.group(1)!.trim();
    }

    setState(() {
      _score += questionScore;
      _conversation.add({
        'role': 'feedback',
        'text': 'Score: $questionScore/10\n$feedback',
      });
      _currentQuestionIndex++;
    });

    if (_currentQuestionIndex < _totalQuestions && followUp.isNotEmpty) {
      setState(() {
        _currentQuestion = followUp;
        _conversation.add({
          'role': 'ai',
          'text': followUp,
        });
        _isProcessing = false;
      });
    } else {
      setState(() => _isProcessing = false);
      _finishViva();
    }
    _scrollToBottom();
  }

  void _finishViva() {
    final maxScore = _totalQuestions * 10;
    final percentage = (_score / maxScore * 100).round();

    final result = {
      'subject': _selectedSubject,
      'chapter': _selectedChapter,
      'score': _score,
      'maxScore': maxScore,
      'percentage': percentage,
      'questionsAsked': _currentQuestionIndex + 1,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
    _showResultsDialog(result);
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    final pct = result['percentage'] as int;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              pct >= 70 ? Icons.emoji_events : Icons.record_voice_over,
              color: pct >= 70 ? Colors.amberAccent : Colors.deepPurpleAccent,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Viva Complete!',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Score', '${result['score']}/${result['maxScore']}'),
            const SizedBox(height: 8),
            _resultRow('Accuracy', '$pct%'),
            const SizedBox(height: 8),
            _resultRow('Questions', '${result['questionsAsked']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _vivaStarted = false;
                _conversation.clear();
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

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) => setState(() => _isListening = false),
    );

    if (available) {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          _textController.text = result.recognizedWords;
        },
        listenFor: const Duration(seconds: 30),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Voice Viva Practice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _vivaStarted ? _buildVivaView() : _buildSetupView(),
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
              onPressed: _isLoading ? null : _startViva,
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
                  : const Icon(Icons.mic),
              label: Text(
                _isLoading ? 'Preparing...' : 'Start Viva',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_results.isNotEmpty) ...[
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

  Widget _buildVivaView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1}/$_totalQuestions',
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
                  'Score: $_score',
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
              final msg = _conversation[index];
              return _buildChatBubble(msg);
            },
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isAi = msg['role'] == 'ai';
    final isFeedback = msg['role'] == 'feedback';

    return Align(
      alignment: isAi || isFeedback
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isFeedback
              ? Colors.amberAccent.withAlpha(20)
              : isAi
                  ? const Color(0xFF1E1E1E)
                  : Colors.deepPurpleAccent.withAlpha(40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFeedback
                ? Colors.amberAccent.withAlpha(40)
                : isAi
                    ? Colors.white.withAlpha(15)
                    : Colors.deepPurpleAccent.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAi || isFeedback)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  isFeedback ? 'Feedback' : 'AI',
                  style: TextStyle(
                    color: isFeedback
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Row(
        children: [
          IconButton(
            onPressed: _isListening ? _stopListening : _startListening,
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.redAccent : Colors.deepPurpleAccent,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type or speak your answer...',
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
            onPressed: _isProcessing || _textController.text.trim().isEmpty
                ? null
                : () {
                    _evaluateAndFollowUp(_textController.text.trim());
                    _textController.clear();
                  },
            icon: Icon(
              Icons.send,
              color: _isProcessing || _textController.text.trim().isEmpty
                  ? Colors.white24
                  : Colors.deepPurpleAccent,
            ),
          ),
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
            child: const Icon(Icons.record_voice_over,
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
                  'Score: ${r['score']}/${r['maxScore']} (${r['percentage']}%)',
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
