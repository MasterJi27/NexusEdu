import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/azure_ai_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

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

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    // Pipeline: user text -> English (Azure Translator) -> AI answers in
    // English -> answer translated back to the selected language. This beats
    // prompting the model to answer in the target language (which drifts into
    // Hinglish). Falls back to the old behavior when translation fails.
    var englishPrompt = text;
    if (_selectedCode != 'en') {
      englishPrompt = await AzureAiService.translate(text, to: 'en', from: _selectedCode);
    }

    final prompt = 'You are a multilingual tutor for Indian students. '
        'Respond entirely in English. Be educational, clear and concise. '
        'Student asks: $englishPrompt';

    String response;
    try {
      response = await AiAgentService.callAgent('custom', {'prompt': prompt});
      if (_selectedCode != 'en') {
        final translated = await AzureAiService.translate(response, to: _selectedCode, from: 'en');
        if (translated.trim().isNotEmpty && translated.trim() != response.trim()) {
          response = translated;
        }
      }
    } catch (_) {
      response = "Sorry, I couldn't reach the server. Check your connection and try again.";
    }

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
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Language Tutor'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpace.sm),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: t.primaryTintBorder),
            ),
            child: Text(
              _selectedLanguage,
              style: context.text.labelSmall?.copyWith(
                color: t.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    final t = context.tokens;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = lang['code'] == _selectedCode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxs, vertical: 6),
            child: GestureDetector(
              onTap: () => _switchLanguage(lang['name']!, lang['code']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? t.primaryTint : t.surface,
                  borderRadius: AppRadius.brPill,
                  border: Border.all(
                    color: isSelected ? t.primaryTintBorder : t.border,
                  ),
                ),
                child: Text(
                  lang['name']!,
                  style: context.text.labelSmall?.copyWith(
                    color: isSelected ? t.primary : t.inkMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
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
    final t = context.tokens;
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
        decoration: BoxDecoration(
          color: t.primaryTint,
          borderRadius: AppRadius.brPill,
        ),
        child: Text(
          text,
          style: context.text.labelSmall?.copyWith(
            color: t.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    final t = context.tokens;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? t.primaryTint : t.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: isUser ? t.primaryTintBorder : t.border,
          ),
        ),
        child: SelectableText(text, style: context.text.bodyMedium),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          )),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      color: t.surface,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: 'Ask in $_selectedLanguage...',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Container(
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
