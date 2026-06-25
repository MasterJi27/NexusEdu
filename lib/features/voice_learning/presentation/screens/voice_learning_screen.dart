import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceLearningScreen extends StatefulWidget {
  const VoiceLearningScreen({super.key});

  @override
  State<VoiceLearningScreen> createState() => _VoiceLearningScreenState();
}

class _VoiceLearningScreenState extends State<VoiceLearningScreen>
    with SingleTickerProviderStateMixin {
  String _selectedLanguage = 'English';
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _transcript = '';
  String _aiResponse = '';
  List<Map<String, String>> _conversationHistory = [];
  List<Map<String, dynamic>> _sessions = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _speechInitialized = false;

  static const List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en-US'},
    {'name': 'Hindi', 'code': 'hi-IN'},
    {'name': 'Hinglish', 'code': 'hi-IN'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
    _initTts();
    _loadSessions();
  }

  Future<void> _initSpeech() async {
    _speechInitialized = await _speechToText.initialize(
      onError: (error) {
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('voice_learning_sessions') ?? [];
    setState(() {
      _sessions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'voice_learning_sessions',
      _sessions.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _toggleListening() async {
    if (!_speechInitialized) {
      await _initSpeech();
      if (!_speechInitialized) return;
    }

    if (_isListening) {
      _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _transcript = '';
        _isListening = true;
      });

      final langCode =
          _languages.firstWhere((l) => l['name'] == _selectedLanguage)['code'];

      await _speechToText.listen(
        onResult: (result) {
          setState(() => _transcript = result.recognizedWords);
          if (result.finalResult) {
            _processVoiceInput(result.recognizedWords);
          }
        },
        localeId: langCode,
        listenMode: ListenMode.dictation,
      );
    }
  }

  Future<void> _processVoiceInput(String text) async {
    if (text.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _aiResponse = '';
    });

    _conversationHistory.add({'role': 'user', 'text': text});

    final langName = _selectedLanguage == 'Hinglish' ? 'Hinglish' : _selectedLanguage;
    final prompt = "You are a helpful AI voice tutor. Respond in $langName. "
        "Keep responses concise and conversational (2-3 sentences max). "
        "Be encouraging and educational. "
        "Previous conversation context: ${_conversationHistory.map((m) => '${m['role']}: ${m['text']}').join('; ')}. "
        "Student just said: $text";

    final response = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    setState(() {
      _aiResponse = response;
      _isProcessing = false;
      _conversationHistory.add({'role': 'ai', 'text': response});
    });

    await _speakResponse(response);

    _sessions.insert(0, {
      'question': text,
      'answer': response,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_sessions.length > 20) _sessions.removeLast();
    _saveSessions();
  }

  Future<void> _speakResponse(String text) async {
    setState(() => _isSpeaking = true);
    final lang = _languages.firstWhere(
      (l) => l['name'] == _selectedLanguage,
      orElse: () => _languages[0],
    );
    await _flutterTts.setLanguage(lang['code'] as String);
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Voice Learning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildLanguageSelector(),
          Expanded(child: _buildConversationView()),
          _buildMicButton(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      height: 46,
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
              onTap: () => setState(() => _selectedLanguage = lang['name']!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.tealAccent.withAlpha(40)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.tealAccent
                        : Colors.white.withAlpha(15),
                  ),
                ),
                child: Text(
                  lang['name']!,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.tealAccent
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

  Widget _buildConversationView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _conversationHistory.length + (_isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _conversationHistory.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.tealAccent),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking...',
                    style: TextStyle(color: Colors.white.withAlpha(120)),
                  ),
                ],
              ),
            ),
          );
        }
        final msg = _conversationHistory[index];
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
              ? Colors.tealAccent.withAlpha(30)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? Colors.tealAccent.withAlpha(30)
                : Colors.white.withAlpha(15),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    ).animate().fade();
  }

  Widget _buildMicButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: GestureDetector(
        onTap: _isProcessing ? null : _toggleListening,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 80 * _pulseAnimation.value,
              height: 80 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isListening
                      ? [Colors.redAccent, Colors.deepOrangeAccent]
                      : [Colors.tealAccent, Colors.deepPurpleAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.redAccent : Colors.tealAccent)
                        .withAlpha(
                            (_isListening ? 80 : 40).round()),
                    blurRadius: 20,
                    spreadRadius: _isListening ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 36,
              ),
            );
          },
        ),
      ),
    ).animate().scale(delay: 200.ms);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_transcript.isNotEmpty)
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _transcript,
                    style: TextStyle(color: Colors.white.withAlpha(200)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (_aiResponse.isNotEmpty && !_isSpeaking)
              IconButton(
                onPressed: () => _speakResponse(_aiResponse),
                icon: const Icon(Icons.volume_up, color: Colors.tealAccent),
                tooltip: 'Replay Response',
              ),
            if (_conversationHistory.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() => _conversationHistory.clear());
                },
                icon: const Icon(Icons.delete_sweep, color: Colors.white54),
                tooltip: 'Clear Chat',
              ),
          ],
        ),
      ),
    );
  }
}
