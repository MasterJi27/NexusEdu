import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class ExocortexScreen extends StatefulWidget {
  const ExocortexScreen({super.key});

  @override
  State<ExocortexScreen> createState() => _ExocortexScreenState();
}

class _ExocortexScreenState extends State<ExocortexScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  late AnimationController _micPulseController;
  Timer? _scanTimer;
  bool _isListening = false;

  final List<Map<String, String>> _whispers = [];
  final List<String> _knowledgeGraph = [];

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadWhispers();
  }

  Future<void> _loadWhispers() async {
    final settings = AppSettings.instance;
    final existing = settings.cachedNotes
        .where((n) => n['type'] == 'exocortex_whispers')
        .toList();
    if (existing.isNotEmpty) {
      final data = json.decode(existing.first['data'] ?? '[]');
      if (data is List) {
        setState(() {
          _whispers.addAll(data.cast<Map<String, String>>());
        });
      }
    }
  }

  Future<void> _saveWhispers() async {
    final settings = AppSettings.instance;
    final updated = [
      {'type': 'exocortex_whispers', 'data': json.encode(_whispers)}
    ];
    await settings.saveCachedNotes(updated);
  }

  Future<void> _whisperKnowledge() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    final whisper = {
      'input': input,
      'context': 'Searching for relevant knowledge...',
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() => _whispers.insert(0, whisper));
    _inputController.clear();

    final aiResponse = await AiService.generateCurriculum(input);

    final updatedWhisper = {
      'input': input,
      'context': aiResponse,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _whispers[0] = updatedWhisper;
      _knowledgeGraph.insert(0, input);
    });
    _saveWhispers();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _micPulseController.repeat(reverse: true);
        _scanTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          _simulateWhisper();
        });
      } else {
        _micPulseController.stop();
        _scanTimer?.cancel();
      }
    });
  }

  void _simulateWhisper() {
    final concepts = [
      'Quantum Computing', 'Neural Plasticity', 'Bayesian Inference',
      'Entropy', 'Game Theory', 'Dark Matter', 'CRISPR', 'Recursion',
    ];
    final rng = Random();
    final concept = concepts[rng.nextInt(concepts.length)];
    final whisper = {
      'input': concept,
      'context': 'Detected while scanning background processes...',
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _whispers.insert(0, whisper);
      _knowledgeGraph.insert(0, concept);
    });
    _saveWhispers();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _micPulseController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Exocortex', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          _buildMicToggle(),
        ],
      ),
      body: Column(
        children: [
          _buildInputBar(),
          if (_knowledgeGraph.isNotEmpty) _buildKnowledgeGraph(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('NEURAL FEED', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
            ),
          ),
          Expanded(child: _buildNeuralFeed()),
        ],
      ),
    );
  }

  Widget _buildMicToggle() {
    return AnimatedBuilder(
      animation: _micPulseController,
      builder: (context, child) {
        final scale = 1.0 + (_micPulseController.value * 0.3);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _toggleListening,
            child: Transform.scale(
              scale: _isListening ? scale : 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.deepPurpleAccent.withAlpha(60)
                      : Colors.white.withAlpha(15),
                  border: Border.all(
                    color: _isListening ? Colors.deepPurpleAccent : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.mic,
                  color: _isListening ? Colors.deepPurpleAccent : Colors.white54,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Paste what you\'re reading/watching...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _whisperKnowledge,
            icon: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeGraph() {
    final chips = _knowledgeGraph.take(12).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KNOWLEDGE GRAPH', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurpleAccent.withAlpha(60)),
              ),
              child: Text(c, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNeuralFeed() {
    if (_whispers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.white.withAlpha(30)),
            const SizedBox(height: 16),
            const Text('Your neural feed is empty', style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Type something above to activate Exocortex', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _whispers.length,
      itemBuilder: (context, index) {
        final whisper = _whispers[index];
        return _buildWhisperCard(whisper, index == 0);
      },
    );
  }

  Widget _buildWhisperCard(Map<String, String> whisper, bool isNew) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNew ? Colors.deepPurpleAccent.withAlpha(20) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew ? Colors.deepPurpleAccent.withAlpha(80) : Colors.white.withAlpha(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 16, color: isNew ? Colors.deepPurpleAccent : Colors.white38),
              const SizedBox(width: 8),
              Text(whisper['input'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(_formatTime(whisper['timestamp'] ?? ''), style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            whisper['context'] ?? '',
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) {
      return '';
    }
  }
}
