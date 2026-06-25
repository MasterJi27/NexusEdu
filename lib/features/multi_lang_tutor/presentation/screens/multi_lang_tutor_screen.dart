import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class MultiLangTutorScreen extends StatefulWidget {
  const MultiLangTutorScreen({super.key});

  @override
  State<MultiLangTutorScreen> createState() => _MultiLangTutorScreenState();
}

class _MultiLangTutorScreenState extends State<MultiLangTutorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String _selectedLanguage = 'English';
  String _selectedCode = 'en';

  static const List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Hindi', 'code': 'hi'},
    {'name': 'Tamil', 'code': 'ta'},
    {'name': 'Telugu', 'code': 'te'},
    {'name': 'Bengali', 'code': 'bn'},
    {'name': 'Marathi', 'code': 'mr'},
    {'name': 'Kannada', 'code': 'kn'},
  ];

  @override
  void initState() {
    super.initState();
    _loadChats();
    if (_messages.isEmpty) {
      _messages.add({'role': 'ai', 'text': 'Welcome! I can explain concepts in any language. Which language would you prefer?'});
    }
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('multi_lang_chats');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      if (last['messages'] != null) {
        _messages = (last['messages'] as List<dynamic>)
            .map<Map<String, String>>((m) => Map<String, String>.from(m))
            .toList();
        _selectedLanguage = last['language'] ?? 'English';
        _selectedCode = last['code'] ?? 'en';
      }
    }
    setState(() {});
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('multi_lang_chats') ?? [];
    history.add(jsonEncode({
      'messages': _messages.length > 30 ? _messages.sublist(_messages.length - 30) : _messages,
      'language': _selectedLanguage,
      'code': _selectedCode,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 30) history.removeAt(0);
    await prefs.setStringList('multi_lang_chats', history);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final prompt = 'You are a multilingual tutor. Respond entirely in $_selectedLanguage ($_selectedCode). '
        'If $_selectedLanguage is not English, use the native script as well. '
        'Be educational and clear. Student asks: $text';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isLoading = false;
    });
    _scrollToBottom();
    _saveChats();
  }

  void _switchLanguage(String lang, String code) {
    setState(() {
      _selectedLanguage = lang;
      _selectedCode = code;
      _messages.add({
        'role': 'system',
        'text': '🔄 Switched to $lang',
      });
    });
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
        title: const Text('Multi-Language Tutor', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(80)),
            ),
            child: Text(_selectedLanguage, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLanguageBar(),
          Expanded(child: _buildChatView()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildLanguageBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = lang['code'] == _selectedCode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: GestureDetector(
              onTap: () => _switchLanguage(lang['name']!, lang['code']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.deepPurpleAccent.withAlpha(50) : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(15),
                  ),
                ),
                child: Text(lang['name']!,
                    style: TextStyle(
                      color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
              ),
            ),
          );
        },
      ),
    ).animate().fade();
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator();
        final msg = _messages[index];
        if (msg['role'] == 'system') return _buildSystemMessage(msg['text']!);
        final isUser = msg['role'] == 'user';
        return _buildChatBubble(msg['text']!, isUser);
      },
    );
  }

  Widget _buildSystemMessage(String text) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ).animate().fade();
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
        child: SelectableText(text, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.5)),
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
                  hintText: 'Ask in $_selectedLanguage...',
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
}
