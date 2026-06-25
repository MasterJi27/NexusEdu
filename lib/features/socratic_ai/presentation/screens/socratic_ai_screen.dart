import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class SocraticAiScreen extends StatefulWidget {
  const SocraticAiScreen({super.key});

  @override
  State<SocraticAiScreen> createState() => _SocraticAiScreenState();
}

class _SocraticAiScreenState extends State<SocraticAiScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  int _round = 0;
  int _ahaMoments = 0;
  bool _answerRevealed = false;
  static const int _maxRounds = 5;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    _ahaMoments = prefs.getInt('socratic_aha_moments') ?? 0;
    final saved = prefs.getStringList('socratic_conversations');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      if (last['round'] != null) {
        _round = 0;
      }
    }
    setState(() {});
  }

  Future<void> _saveConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = prefs.getStringList('socratic_conversations') ?? [];
    final entry = jsonEncode({
      'messages': _messages,
      'round': _round,
      'ahaMoments': _ahaMoments,
      'timestamp': DateTime.now().toIso8601String(),
    });
    conversations.add(entry);
    if (conversations.length > 50) conversations.removeAt(0);
    await prefs.setStringList('socratic_conversations', conversations);
    await prefs.setInt('socratic_aha_moments', _ahaMoments);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading || _answerRevealed) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    _round++;

    String response;
    if (_round >= _maxRounds) {
      final aiResponse = await AiAgentService.callAgent('custom', {
        'prompt': 'The student has been asking questions using Socratic method for '
            '$_maxRounds rounds. Now reveal the answer with a clear explanation. '
            'Be encouraging. Previous conversation:\n'
            '${_messages.map((m) => '${m["role"]}: ${m["text"]}').join("\n")}',
      });
      response = '💡 Great thinking! Here is the answer:\n\n$aiResponse';
      _answerRevealed = true;
    } else {
      final prompt = 'You are a Socratic tutor. The student asks: "$text". '
          'Round ${_round + 1} of $_maxRounds. '
          'NEVER give the answer directly. Instead ask a thought-provoking '
          'follow-up question that guides the student closer to the answer. '
          'Be encouraging and curious. Previous messages:\n'
          '${_messages.map((m) => '${m["role"]}: ${m["text"]}').join("\n")}';
      response = await AiAgentService.callAgent('custom', {'prompt': prompt});
    }

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isLoading = false;
    });
    _scrollToBottom();
    _saveConversation();
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

  void _startNewConversation() {
    setState(() {
      _messages = [];
      _round = 0;
      _answerRevealed = false;
    });
    _saveConversation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Socratic AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildAhaCounter(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _startNewConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(child: _buildChatView()),
          if (_answerRevealed) _buildRevealBanner(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAhaCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb, color: Colors.amberAccent, size: 16),
          const SizedBox(width: 4),
          Text('$_ahaMoments', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.deepPurpleAccent, size: 20),
          const SizedBox(width: 8),
          Text('Round ${_round + 1} of $_maxRounds',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _round / _maxRounds,
                backgroundColor: Colors.white.withAlpha(20),
                valueColor: const AlwaysStoppedAnimation(Colors.deepPurpleAccent),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildChatView() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.question_answer, size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
            const SizedBox(height: 16),
            Text('Ask me anything!', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 18)),
            const SizedBox(height: 8),
            Text('I\'ll guide you to the answer with questions',
                style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return _buildChatBubble(msg['text']!, isUser);
      },
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.deepPurpleAccent.withAlpha(40)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? Colors.deepPurpleAccent.withAlpha(40)
                : Colors.white.withAlpha(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Socratic Guide', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            SelectableText(text, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: isUser ? 0.1 : -0.1);
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(150),
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(
            delay: Duration(milliseconds: i * 200),
          ).then(delay: Duration(milliseconds: 200)).fadeOut()),
        ),
      ),
    );
  }

  Widget _buildRevealBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.deepPurpleAccent.withAlpha(30),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.amberAccent, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Answer Revealed! Great Socratic journey!',
                style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _ahaMoments++);
              _saveConversation();
            },
            child: const Text('+Aha Moment', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.5);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_answerRevealed,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _answerRevealed ? 'Start a new conversation' : 'Ask a question...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.deepPurpleAccent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: _answerRevealed
                    ? Colors.white.withAlpha(20)
                    : Colors.deepPurpleAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: (_isLoading || _answerRevealed) ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent))
                    : Icon(Icons.send, color: _answerRevealed ? Colors.white.withAlpha(50) : Colors.deepPurpleAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
