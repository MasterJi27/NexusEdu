import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HindiTutorScreen extends StatefulWidget {
  const HindiTutorScreen({super.key});

  @override
  State<HindiTutorScreen> createState() => _HindiTutorScreenState();
}

class _HindiTutorScreenState extends State<HindiTutorScreen> {
  String _selectedLanguage = 'Hindi';
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _chatHistory = [];

  static const List<Map<String, String>> _languages = [
    {'name': 'Hindi', 'code': 'hi', 'greeting': 'नमस्ते! मैं आपका AI ट्यूटर हूँ।'},
    {'name': 'Marathi', 'code': 'mr', 'greeting': 'नमस्कार! मी तुमचा AI शिक्षक आहे.'},
    {'name': 'Tamil', 'code': 'ta', 'greeting': 'வணக்கம்! நான் உங்கள் AI ஆசிரியர்.'},
    {'name': 'Telugu', 'code': 'te', 'greeting': 'నమస్కారం! నేను మీ AI టీచర్ ని.'},
    {'name': 'Bengali', 'code': 'bn', 'greeting': 'নমস্কার! আমি আপনার AI শিক্ষক।'},
    {'name': 'Kannada', 'code': 'kn', 'greeting': 'ನಮಸ್ಕಾರ! ನಾನು ನಿಮ್ಮ AI ಶಿಕ್ಷಕ.'},
    {'name': 'Malayalam', 'code': 'ml', 'greeting': 'നമസ്കാരം! ഞാൻ നിങ്ങളുടെ AI അധ്യാപകൻ ആണ്.'},
    {'name': 'Gujarati', 'code': 'gu', 'greeting': 'નમસ્તે! હું તમારો AI શિક્ષક છું.'},
    {'name': 'Punjabi', 'code': 'pa', 'greeting': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਤੁਹਾਡਾ AI ਅਧਿਆਪਕ ਹਾਂ.'},
  ];

  @override
  void initState() {
    super.initState();
    _loadChats();
    if (_messages.isEmpty) {
      final greeting =
          _languages.firstWhere((l) => l['name'] == _selectedLanguage)['greeting']!;
      _messages.add({'role': 'ai', 'text': greeting});
    }
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('hindi_tutor_chats') ?? [];
    setState(() {
      _chatHistory = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'hindi_tutor_chats',
      _chatHistory.map((e) => json.encode(e)).toList(),
    );
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

    final langData =
        _languages.firstWhere((l) => l['name'] == _selectedLanguage);
    final langCode = langData['code'];

    final prompt = "You are a friendly, encouraging AI tutor teaching in $_selectedLanguage. "
        "The student is learning in ${langData['name']}. "
        "Respond ENTIRELY in ${langData['name']} (${langCode} script). "
        "Be educational, patient, and motivating. "
        "Use simple, clear language appropriate for a student. "
        "Student says: $text";

    final response = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isLoading = false;
    });
    _scrollToBottom();

    _chatHistory.insert(0, {
      'language': _selectedLanguage,
      'lastMessage': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_chatHistory.length > 30) _chatHistory.removeLast();
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

  void _clearChat() {
    setState(() {
      _messages.clear();
      final greeting =
          _languages.firstWhere((l) => l['name'] == _selectedLanguage)['greeting']!;
      _messages.add({'role': 'ai', 'text': greeting});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'AI Language Tutor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white70),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLanguageSelector(),
          Expanded(child: _buildChatView()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = lang['name'] == _selectedLanguage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLanguage = lang['name']!;
                  _clearChat();
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurpleAccent.withAlpha(50)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.deepPurpleAccent
                        : Colors.white.withAlpha(15),
                  ),
                ),
                child: Text(
                  lang['name']!,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.deepPurpleAccent
                        : Colors.white.withAlpha(150),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
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
      itemCount: _messages.length,
      itemBuilder: (context, index) {
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
        child: SelectableText(
          text,
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    ).animate().fade().slideY(begin: isUser ? 0.1 : -0.1);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask a question in $_selectedLanguage...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.deepPurpleAccent.withAlpha(120)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurpleAccent,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.deepPurpleAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
