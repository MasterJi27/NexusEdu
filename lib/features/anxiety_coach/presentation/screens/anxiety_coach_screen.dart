import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class AnxietyCoachScreen extends StatefulWidget {
  const AnxietyCoachScreen({super.key});

  @override
  State<AnxietyCoachScreen> createState() => _AnxietyCoachScreenState();
}

class _AnxietyCoachScreenState extends State<AnxietyCoachScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  double _moodBefore = 5.0;
  double _moodAfter = 5.0;
  bool _showMoodBefore = true;
  bool _breathingActive = false;
  int _breathingPhase = 0;
  int _breathingSeconds = 0;
  Timer? _breathingTimer;

  static const List<String> _calmingQuotes = [
    'Breathe. You are stronger than you think.',
    'This too shall pass. Nothing is permanent.',
    'You are not your thoughts. You are the observer.',
    'Peace comes from within. Do not seek it without.',
    'The present moment is filled with joy and happiness.',
    'Feelings are just visitors, let them come and go.',
    'You are exactly where you need to be.',
    'Take it one breath at a time.',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
    if (_messages.isEmpty) {
      _messages.add({
        'role': 'ai',
        'text': 'Welcome to Anxiety Coach. I\'m here to help you feel calmer. '
            'How are you feeling right now?'
      });
    }
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('anxiety_sessions');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      if (last['messages'] != null) {
        _messages = (last['messages'] as List<dynamic>)
            .map<Map<String, String>>((m) => Map<String, String>.from(m))
            .toList();
      }
    }
    setState(() {});
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('anxiety_sessions') ?? [];
    history.add(jsonEncode({
      'messages': _messages.length > 30 ? _messages.sublist(_messages.length - 30) : _messages,
      'moodBefore': _moodBefore,
      'moodAfter': _moodAfter,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 30) history.removeAt(0);
    await prefs.setStringList('anxiety_sessions', history);
  }

  bool _detectStress(String text) {
    final stressKeywords = ['anxious', 'stressed', 'worried', 'panic', 'nervous', 'scared',
      'overwhelmed', 'tired', 'depressed', 'sad', 'fear', 'hopeless', 'tense'];
    final lower = text.toLowerCase();
    return stressKeywords.any((k) => lower.contains(k));
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final hasStress = _detectStress(text);

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    String prompt;
    if (hasStress) {
      prompt = 'The student seems stressed. Their message: "$text". '
          'Respond with empathy. Suggest a breathing exercise (4-7-8 technique). '
          'Include a calming quote from either Hindi or English. '
          'Be warm, gentle, and supportive. Keep response under 100 words.';
    } else {
      prompt = 'You are an anxiety coach. The student says: "$text". '
          'Respond with empathy and support. If appropriate, suggest coping strategies. '
          'Be warm and understanding. Keep response under 80 words.';
    }

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _startBreathing() {
    setState(() {
      _breathingActive = true;
      _breathingPhase = 0;
      _breathingSeconds = 0;
    });

    _breathingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _breathingSeconds++;
        if (_breathingPhase == 0 && _breathingSeconds >= 4) {
          _breathingPhase = 1;
          _breathingSeconds = 0;
        } else if (_breathingPhase == 1 && _breathingSeconds >= 7) {
          _breathingPhase = 2;
          _breathingSeconds = 0;
        } else if (_breathingPhase == 2 && _breathingSeconds >= 8) {
          _breathingPhase = 0;
          _breathingSeconds = 0;
        }
      });
    });
  }

  void _stopBreathing() {
    _breathingTimer?.cancel();
    setState(() {
      _breathingActive = false;
      _breathingPhase = 0;
      _breathingSeconds = 0;
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
        title: const Text('Anxiety Coach', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_breathingActive ? Icons.stop_circle : Icons.air, color: Colors.tealAccent),
            onPressed: _breathingActive ? _stopBreathing : _startBreathing,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_breathingActive) _buildBreathingWidget(),
          _buildMoodSlider(),
          Expanded(child: _buildChatView()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMoodSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          const Icon(Icons.mood, color: Colors.amberAccent, size: 18),
          const SizedBox(width: 8),
          Text(_showMoodBefore ? 'Current mood' : 'After session',
              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
          Expanded(
            child: Slider(
              value: _showMoodBefore ? _moodBefore : _moodAfter,
              min: 1, max: 10,
              divisions: 9,
              activeColor: Colors.deepPurpleAccent,
              inactiveColor: Colors.white.withAlpha(20),
              onChanged: (v) {
                setState(() {
                  if (_showMoodBefore) {
                    _moodBefore = v;
                  } else {
                    _moodAfter = v;
                  }
                });
              },
            ),
          ),
          Text('${(_showMoodBefore ? _moodBefore : _moodAfter).toInt()}/10',
              style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _showMoodBefore = !_showMoodBefore);
              if (!_showMoodBefore) _saveSession();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_showMoodBefore ? 'After' : 'Before',
                  style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildBreathingWidget() {
    final phases = ['Inhale', 'Hold', 'Exhale'];
    final durations = [4, 7, 8];
    final colors = [Colors.cyanAccent, Colors.amberAccent, Colors.greenAccent];
    final currentPhase = phases[_breathingPhase];
    final currentColor = colors[_breathingPhase];
    final remaining = durations[_breathingPhase] - _breathingSeconds;
    final progress = _breathingSeconds / durations[_breathingPhase];

    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Text(currentPhase, style: TextStyle(color: currentColor, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: 100, height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withAlpha(20),
                  valueColor: AlwaysStoppedAnimation(currentColor),
                ),
                Text('$remaining', style: TextStyle(color: currentColor, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('4-7-8 Breathing', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
        ],
      ),
    ).animate().fade().slideY(begin: -0.3);
  }

  Widget _buildChatView() {
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
                decoration: BoxDecoration(color: Colors.tealAccent.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                child: const Text('Anxiety Coach', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
            decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, color: Colors.tealAccent, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calmingQuotes[Random().nextInt(_calmingQuotes.length)],
                      style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Share how you feel...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.tealAccent)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                        : const Icon(Icons.send, color: Colors.tealAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
