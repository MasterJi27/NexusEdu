import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoricalTravelScreen extends StatefulWidget {
  const HistoricalTravelScreen({super.key});

  @override
  State<HistoricalTravelScreen> createState() => _HistoricalTravelScreenState();
}

class _HistoricalTravelScreenState extends State<HistoricalTravelScreen> {
  String _selectedEra = 'Ancient India';
  String _selectedTopic = '';
  bool _isLoading = false;
  bool _travelStarted = false;
  bool _isProcessing = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _chatMessages = [];
  String _characterName = '';
  String _characterIntro = '';
  List<Map<String, dynamic>> _pastChats = [];

  final Map<String, List<String>> _topicsByEra = {
    'Ancient India': [
      'Indus Valley Civilization',
      'Vedic Period',
      'Maurya Empire',
      'Gupta Golden Age',
      'Ashoka\'s Reign',
    ],
    'Medieval India': [
      'Mughal Empire',
      'Delhi Sultanate',
      'Vijayanagara Empire',
      'Bhakti Movement',
      'Maratha Empire',
    ],
    'Modern India': [
      'Freedom Struggle',
      'Quit India Movement',
      'Partition of India',
      'Indian Independence',
      'Post-Independence Era',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedTopic = _topicsByEra[_selectedEra]!.first;
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
    final saved = prefs.getStringList('history_chats') ?? [];
    setState(() {
      _pastChats = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _travelBack() async {
    setState(() {
      _isLoading = true;
      _chatMessages = [];
    });

    final prompt =
        'You are roleplaying as a historical figure from $_selectedEra '
        'related to $_selectedTopic.\n'
        'Introduce yourself in character. State your name, your role in history, '
        'and a brief greeting. Stay in character. Keep it under 100 words.';

    try {
      final response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
      _characterIntro = response;
      final nameMatch = RegExp(r'I am (\w[\w\s]*?)[\.,!]').firstMatch(response);
      _characterName = nameMatch?.group(1)?.trim() ?? 'Historical Figure';
    } catch (_) {
      _characterName = 'A Historical Figure';
      _characterIntro =
          'Greetings! I am a figure from $_selectedEra. '
          'Ask me anything about $_selectedTopic.';
    }

    setState(() {
      _isLoading = false;
      _travelStarted = true;
      _chatMessages.add({
        'role': 'character',
        'text': _characterIntro,
      });
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

    final chatHistory = _chatMessages
        .map((m) =>
            '${m['role'] == 'user' ? 'Student' : _characterName}: ${m['text']}')
        .join('\n');

    final prompt =
        'You are $_characterName from $_selectedEra, discussing $_selectedTopic.\n'
        'Conversation so far:\n$chatHistory\n\n'
        'Respond in character. Stay historically accurate. '
        'If asked something outside your era, politely redirect. '
        'Keep responses under 150 words.';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'I apologize, but I cannot respond right now. '
          'Please try again in a moment.';
    }

    setState(() {
      _chatMessages.add({'role': 'character', 'text': response});
      _isProcessing = false;
    });
    _scrollToBottom();
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

  void _resetTravel() {
    setState(() {
      _travelStarted = false;
      _chatMessages = [];
      _characterName = '';
      _characterIntro = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Historical Time Travel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_travelStarted)
            IconButton(
              onPressed: _resetTravel,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _travelStarted ? _buildChatView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_edu,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Travel Through Time',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Meet historical figures and ask them questions.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildEraSelector(),
          const SizedBox(height: 16),
          _buildTopicSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _travelBack,
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
                  : const Icon(Icons.time_to_leave),
              label: Text(
                _isLoading ? 'Traveling...' : 'Travel Back',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastChats.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Journeys',
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
                        color: Colors.amberAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.amberAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['character'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${c['era']} • ${(c['messages'] as List?)?.length ?? 0} messages',
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

  Widget _buildEraSelector() {
    return _buildChipSelector(
      'Era',
      ['Ancient India', 'Medieval India', 'Modern India'],
      _selectedEra,
      (val) => setState(() {
        _selectedEra = val!;
        _selectedTopic = _topicsByEra[_selectedEra]!.first;
      }),
    );
  }

  Widget _buildTopicSelector() {
    final topics = _topicsByEra[_selectedEra]!;
    return _buildChipSelector(
      'Topic',
      topics,
      _selectedTopic,
      (val) => setState(() => _selectedTopic = val!),
    );
  }

  Widget _buildChipSelector(
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

  Widget _buildChatView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.amberAccent.withAlpha(30),
                child:
                    const Icon(Icons.person, color: Colors.amberAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _characterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _selectedTopic,
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _selectedEra,
                  style: const TextStyle(
                    color: Colors.amberAccent,
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
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
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
                : Colors.amberAccent.withAlpha(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                isUser ? 'You' : _characterName,
                style: TextStyle(
                  color: isUser
                      ? Colors.deepPurpleAccent
                      : Colors.amberAccent,
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
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask ${_characterName}...',
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
}
