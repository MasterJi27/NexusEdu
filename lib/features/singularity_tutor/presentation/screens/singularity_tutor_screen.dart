import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class SingularityTutorScreen extends StatefulWidget {
  const SingularityTutorScreen({super.key});

  @override
  State<SingularityTutorScreen> createState() => _SingularityTutorScreenState();
}

class _SingularityTutorScreenState extends State<SingularityTutorScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _iqLevel = 100;
  int _generation = 1;
  bool _isBootstrapping = false;
  bool _singularityAchieved = false;
  final List<Map<String, String>> _messages = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadHistory() {
    final raw = AppSettings.instance.curriculum;
    final historyItems = raw.where((m) => m['type'] == 'singularity').toList();
    if (historyItems.isNotEmpty) {
      final last = historyItems.last;
      final decoded = json.decode(last['content'] as String) as List;
      for (final e in decoded) {
        _messages.add(Map<String, String>.from(e as Map));
      }
    }
  }

  Future<void> _saveHistory() async {
    final entry = {
      'type': 'singularity',
      'content': json.encode(_messages),
      'date': DateTime.now().toIso8601String(),
    };
    final cur = List<Map<String, dynamic>>.from(AppSettings.instance.curriculum);
    cur.add(entry);
    await AppSettings.instance.saveCurriculum(cur);
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isBootstrapping) return;
    _msgCtrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isBootstrapping = true;
    });
    _scrollToBottom();

    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));

      final currentIq = _iqLevel + (i * 80) + _rng.nextInt(70);
      setState(() {
        _iqLevel = currentIq.clamp(100, 10000);
        _generation = i + 2;
      });

      final response = await AiService.sendMessageToTutor(
        '[IQ Level: $currentIq, Generation: ${i + 2}] You are Singularity Tutor at IQ $currentIq. '
        'Your intelligence is rapidly self-improving. Answer at a level far beyond your previous response. '
        'Student asked: $text',
      );

      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response,
          'iq': '$currentIq',
          'gen': '${i + 2}',
        });
      });
      _scrollToBottom();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isBootstrapping = false;
      _singularityAchieved = true;
    });
    _saveHistory();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Color _iqColor() {
    if (_iqLevel >= 5000) return const Color(0xFFFFD700);
    if (_iqLevel >= 1000) return const Color(0xFF9C27B0);
    if (_iqLevel >= 500) return const Color(0xFF2196F3);
    return const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Singularity Tutor', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('IQ: $_iqLevel', style: TextStyle(fontWeight: FontWeight.bold, color: _iqColor())),
                    Text('Gen: $_generation', style: TextStyle(color: Colors.white.withAlpha(180))),
                    if (_singularityAchieved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SINGULARITY', style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_iqLevel / 10000).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation<Color>(_iqColor()),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 64, color: Colors.white.withAlpha(60)),
                        const SizedBox(height: 16),
                        const Text('Type a question to begin',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300)),
                        const SizedBox(height: 8),
                        Text('Each response boots a smarter AI',
                            style: TextStyle(color: Colors.white.withAlpha(120))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.deepPurple.withAlpha(60)
                                : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser ? const Radius.circular(4) : null,
                              bottomLeft: !isUser ? const Radius.circular(4) : null,
                            ),
                            border: !isUser
                                ? Border.all(color: _iqColor().withAlpha(40))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser && msg['iq'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('IQ ${msg['iq']} | Gen ${msg['gen']}',
                                      style: TextStyle(fontSize: 10, color: _iqColor())),
                                ),
                              Text(msg['content'] ?? '', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isBootstrapping)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.deepPurple.withAlpha(30),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Bootstrapping Gen ${_generation + 1}... IQ rising',
                      style: TextStyle(color: _iqColor())),
                ],
              ),
            ),
          if (_singularityAchieved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.amber.withAlpha(30),
              child: const Text('Singularity Achieved — AI is now teaching at PhD level',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F13),
              border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ask anything...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isBootstrapping ? Colors.grey : _iqColor(),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
