import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageExchangeScreen extends StatefulWidget {
  const LanguageExchangeScreen({super.key});

  @override
  State<LanguageExchangeScreen> createState() => _LanguageExchangeScreenState();
}

class _LanguageExchangeScreenState extends State<LanguageExchangeScreen> {
  String _userLanguage = 'Hindi';
  String _targetLanguage = 'English';
  bool _isLoading = false;
  bool _sessionStarted = false;
  bool _isProcessing = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _chatMessages = [];
  List<Map<String, dynamic>> _vocabulary = [];
  String _grammarTip = '';
  List<Map<String, dynamic>> _pastChats = [];

  final List<String> _languages = [
    'Hindi',
    'English',
    'Tamil',
    'Telugu',
    'Bengali',
    'Marathi',
    'Gujarati',
    'Kannada',
    'Malayalam',
    'Punjabi',
  ];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('language_chats') ?? [];
    setState(() {
      _pastChats = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _chatMessages = [];
      _vocabulary = [];
    });

    final prompt =
        'You are a language exchange partner helping someone learn $_targetLanguage. '
        'Their native language is $_userLanguage.\n'
        'Greet them in $_targetLanguage, then provide the translation in $_userLanguage. '
        'Add a vocabulary word of the day. Keep it friendly and encouraging.';

    try {
      final response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
      _chatMessages.add({'role': 'partner', 'text': response});
    } catch (_) {
      _chatMessages.add({
        'role': 'partner',
        'text': 'Welcome! Let\'s practice $_targetLanguage together.',
      });
    }

    setState(() {
      _isLoading = false;
      _sessionStarted = true;
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _chatMessages.add({'role': 'user', 'text': text});
    });
    _scrollToBottom();
    _messageController.clear();

    final prompt =
        'You are a language exchange partner teaching $_targetLanguage. '
        'The student\'s native language is $_userLanguage.\n'
        'The student said: "$text"\n\n'
        'Respond in $_targetLanguage. If they made a mistake, gently correct it. '
        'Include the correction and translation in $_userLanguage. '
        'Add one new vocabulary word with meaning. '
        'Keep it conversational and encouraging.';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'Good effort! Keep practicing $_targetLanguage.';
    }

    setState(() {
      _chatMessages.add({'role': 'partner', 'text': response});
      _vocabulary.add({
        'word': 'Practice',
        'meaning': 'To learn a skill repeatedly',
      });
      _isProcessing = false;
    });
    _scrollToBottom();

    if (_chatMessages.length % 3 == 0) {
      _loadGrammarTip();
    }
  }

  Future<void> _loadGrammarTip() async {
    try {
      final tip = await AiAgentService.callAgent(
        'custom',
        {'prompt': 'Give one short grammar tip for learning $_targetLanguage. Keep it under 30 words.'},
      );
      setState(() => _grammarTip = tip);
    } catch (_) {}
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

  void _resetSession() {
    setState(() {
      _sessionStarted = false;
      _chatMessages = [];
      _vocabulary = [];
      _grammarTip = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Language Exchange Partner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_sessionStarted)
            IconButton(
              onPressed: _resetSession,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _sessionStarted ? _buildChatView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.translate,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Practice Languages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chat with an AI partner who corrects your mistakes.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildLanguageRow(),
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
                  : const Icon(Icons.chat),
              label: Text(
                _isLoading ? 'Starting...' : 'Start Chat',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastChats.isNotEmpty) ...[
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
            ...List.generate(_pastChats.length.clamp(0, 5), (i) {
              final c = _pastChats[i];
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
                        color: Colors.tealAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.translate,
                          color: Colors.tealAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c['userLang']} → ${c['targetLang']}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(c['messages'] as List?)?.length ?? 0} messages',
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

  Widget _buildLanguageRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildLanguageDropdown(
                  'Your Language',
                  _userLanguage,
                  (val) => setState(() => _userLanguage = val!),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.swap_horiz,
                    color: Colors.deepPurpleAccent, size: 24),
              ),
              Expanded(
                child: _buildLanguageDropdown(
                  'Target Language',
                  _targetLanguage,
                  (val) => setState(() => _targetLanguage = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildLanguageDropdown(
    String label,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(150),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButton<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          underline: const SizedBox.shrink(),
          items: _languages
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.translate,
                    color: Colors.tealAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_userLanguage → $_targetLanguage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_grammarTip.isNotEmpty)
                GestureDetector(
                  onTap: () => _showGrammarTip(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Grammar Tip',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
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
            itemCount: _chatMessages.length + (_vocabulary.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chatMessages.length) {
                return _buildVocabularyCard();
              }
              return _buildChatBubble(_chatMessages[index]);
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
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.deepPurpleAccent.withAlpha(40)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser
                ? Colors.deepPurpleAccent.withAlpha(60)
                : Colors.tealAccent.withAlpha(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                isUser ? 'You' : 'Partner',
                style: TextStyle(
                  color: isUser
                      ? Colors.deepPurpleAccent
                      : Colors.tealAccent,
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

  Widget _buildVocabularyCard() {
    if (_vocabulary.isEmpty) return const SizedBox.shrink();
    final last = _vocabulary.last;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vocabulary',
            style: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${last['word']}: ${last['meaning']}',
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
            ),
          ),
        ],
      ),
    ).animate().fade();
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
                  hintText: 'Type in $_userLanguage or $_targetLanguage...',
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
          ],
        ),
      ),
    );
  }

  void _showGrammarTip() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grammar Tip',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _grammarTip,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
