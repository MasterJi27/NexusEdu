import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class PersonalizedTutorScreen extends StatefulWidget {
  const PersonalizedTutorScreen({super.key});

  @override
  State<PersonalizedTutorScreen> createState() => _PersonalizedTutorScreenState();
}

class _PersonalizedTutorScreenState extends State<PersonalizedTutorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _showProfile = false;
  int _totalMessages = 0;
  double _visualStyle = 33.0;
  double _readingStyle = 34.0;
  double _auditoryStyle = 33.0;

  @override
  void initState() {
    super.initState();
    _loadChats();
    if (_messages.isEmpty) {
      _messages.add({'role': 'ai', 'text': 'Hi! I\'m your Personalized Tutor. I adapt to your learning style. Ask me anything!'});

      final rng = Random();
      _visualStyle = 20 + rng.nextDouble() * 60;
      _readingStyle = 20 + rng.nextDouble() * (80 - _visualStyle);
      _auditoryStyle = 100 - _visualStyle - _readingStyle;
    }
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('personalized_tutor_chats');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      if (last['messages'] != null) {
        _messages = (last['messages'] as List<dynamic>)
            .map<Map<String, String>>((m) => Map<String, String>.from(m))
            .toList();
        _totalMessages = last['totalMessages'] ?? 0;
      }
    }
    setState(() {});
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('personalized_tutor_chats') ?? [];
    history.add(jsonEncode({
      'messages': _messages.length > 20 ? _messages.sublist(_messages.length - 20) : _messages,
      'totalMessages': _totalMessages,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 30) history.removeAt(0);
    await prefs.setStringList('personalized_tutor_chats', history);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
      _totalMessages++;
    });
    _inputController.clear();
    _scrollToBottom();

    final dominantStyle = _visualStyle > _readingStyle && _visualStyle > _auditoryStyle
        ? 'visual'
        : _readingStyle > _auditoryStyle ? 'reading' : 'auditory';

    final prompt = 'You are a personalized tutor. The student\'s dominant learning style is $dominantStyle '
        '(Visual: ${_visualStyle.toStringAsFixed(0)}%, Reading: ${_readingStyle.toStringAsFixed(0)}%, '
        'Auditory: ${_auditoryStyle.toStringAsFixed(0)}%). '
        'Adapt your response accordingly. '
        '${dominantStyle == "visual" ? "Use visual descriptions, diagrams in text, and spatial references." : ""}'
        '${dominantStyle == "reading" ? "Provide detailed text explanations with examples and written references." : ""}'
        '${dominantStyle == "auditory" ? "Use conversational tone, rhythm, and suggest the student speak aloud." : ""}'
        '\nStudent asks: $text';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isLoading = false;
    });
    _scrollToBottom();
    _saveChats();
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
        title: const Text('Personalized Tutor', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showProfile ? Icons.chat : Icons.person, color: Colors.white70),
            onPressed: () => setState(() => _showProfile = !_showProfile),
          ),
        ],
      ),
      body: _showProfile ? _buildProfilePanel() : _buildChatView(),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(child: _buildMessages()),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
            const SizedBox(height: 16),
            Text('Ask anything!', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 18)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator();
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
          color: isUser ? Colors.deepPurpleAccent.withAlpha(40) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: isUser ? Colors.deepPurpleAccent.withAlpha(40) : Colors.white.withAlpha(15)),
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
                child: const Text('Tutor', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.deepPurpleAccent, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(delay: Duration(milliseconds: i * 200)).then(delay: const Duration(milliseconds: 200)).fadeOut()),
        ),
      ),
    );
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.deepPurpleAccent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent))
                    : const Icon(Icons.send, color: Colors.deepPurpleAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePanel() {
    final dominantStyle = _visualStyle > _readingStyle && _visualStyle > _auditoryStyle
        ? 'Visual'
        : _readingStyle > _auditoryStyle ? 'Reading' : 'Auditory';
    final dominantColor = dominantStyle == 'Visual'
        ? Colors.cyanAccent
        : dominantStyle == 'Reading' ? Colors.greenAccent : Colors.orangeAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dominantColor.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.psychology, color: dominantColor, size: 40),
                ),
                const SizedBox(height: 12),
                Text(dominantStyle, style: TextStyle(color: dominantColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Learning Style', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 24),
                _buildStyleBar('Visual', _visualStyle, Colors.cyanAccent),
                const SizedBox(height: 12),
                _buildStyleBar('Reading', _readingStyle, Colors.greenAccent),
                const SizedBox(height: 12),
                _buildStyleBar('Auditory', _auditoryStyle, Colors.orangeAccent),
                const SizedBox(height: 20),
                Text('Total conversations: $_totalMessages', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
              ],
            ),
          ).animate().fade().scale(),
        ],
      ),
    );
  }

  Widget _buildStyleBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${value.toStringAsFixed(0)}%', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.white.withAlpha(20),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}
