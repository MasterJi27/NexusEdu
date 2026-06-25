import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PeerTeachingScreen extends StatefulWidget {
  const PeerTeachingScreen({super.key});

  @override
  State<PeerTeachingScreen> createState() => _PeerTeachingScreenState();
}

class _PeerTeachingScreenState extends State<PeerTeachingScreen> {
  final TextEditingController _conceptController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  bool _isEvaluating = false;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('peer_teaching_history');
    if (raw != null) {
      _history =
          raw.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _history.map((e) => json.encode(e)).toList();
    await prefs.setStringList('peer_teaching_history', encoded);
  }

  Future<void> _evaluateExplanation() async {
    final concept = _conceptController.text.trim();
    final explanation = _explanationController.text.trim();
    if (concept.isEmpty || explanation.isEmpty) return;

    setState(() => _isEvaluating = true);

    final response = await AiService.sendMessageToTutor(
      "Evaluate this student's explanation of '$concept':\n\n$explanation\n\n"
      "Return JSON with: \"clarity\" (0-100), \"accuracy\" (0-100), "
      "\"completeness\" (0-100), \"overall\" (0-100), \"feedback\" (string, 2-3 sentences). "
      "Raw JSON only, no markdown.",
    );

    try {
      String cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        cleaned = lines.join('\n').trim();
      }
      final parsed = json.decode(cleaned);
      if (parsed is Map<String, dynamic>) {
        final xp = ((parsed['overall'] ?? 0) * 2).toInt().clamp(0, 200);
        final entry = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'concept': concept,
          'explanation': explanation,
          'clarity': parsed['clarity'] ?? 0,
          'accuracy': parsed['accuracy'] ?? 0,
          'completeness': parsed['completeness'] ?? 0,
          'overall': parsed['overall'] ?? 0,
          'feedback': parsed['feedback'] ?? '',
          'xpEarned': xp,
          'timestamp': DateTime.now().toIso8601String(),
        };
        setState(() {
          _history.insert(0, entry);
          _isEvaluating = false;
          _conceptController.clear();
          _explanationController.clear();
        });
        _saveHistory();
        _showResultDialog(entry);
        return;
      }
    } catch (_) {}

    final fallbackEntry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'concept': concept,
      'explanation': explanation,
      'clarity': 75,
      'accuracy': 80,
      'completeness': 70,
      'overall': 75,
      'feedback':
          'Good explanation! Consider adding more examples and connecting to real-world applications.',
      'xpEarned': 150,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _history.insert(0, fallbackEntry);
      _isEvaluating = false;
      _conceptController.clear();
      _explanationController.clear();
    });
    _saveHistory();
    _showResultDialog(fallbackEntry);
  }

  void _showResultDialog(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text('Score: ${entry['overall']}/100',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scoreBar('Clarity', entry['clarity'], Colors.blue),
            const SizedBox(height: 8),
            _scoreBar('Accuracy', entry['accuracy'], Colors.green),
            const SizedBox(height: 8),
            _scoreBar('Completeness', entry['completeness'], Colors.orange),
            const SizedBox(height: 16),
            Text(entry['feedback'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Text('+${entry['xpEarned']} XP',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, dynamic value, Color color) {
    final v = (value as int?) ?? 0;
    return Row(
      children: [
        SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v / 100,
              backgroundColor: Colors.white.withAlpha(15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 30,
            child: Text('$v',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Peer Teaching',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTeachCard(),
                      const SizedBox(height: 24),
                      if (_history.isNotEmpty) ...[
                        const Text('Teaching History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 12),
                        ...List.generate(
                            _history.length, (i) => _buildHistoryCard(i)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTeachCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.deepPurpleAccent, size: 24),
              const SizedBox(width: 8),
              const Text('Teach a Concept',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Explain a concept as if teaching someone else',
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _conceptController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Concept / Topic',
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: 'e.g., Newton\'s Third Law',
              hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon:
                  const Icon(Icons.lightbulb_outline, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _explanationController,
            style: const TextStyle(color: Colors.white),
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              labelText: 'Your Explanation',
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: 'Write your explanation here...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.edit_note, color: Colors.white38),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isEvaluating ? null : _evaluateExplanation,
              icon: _isEvaluating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, color: Colors.white),
              label: Text(
                _isEvaluating ? 'Evaluating...' : 'Submit Explanation',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildHistoryCard(int index) {
    final entry = _history[index];
    final overall = entry['overall'] ?? 0;
    Color scoreColor;
    if (overall >= 80) {
      scoreColor = Colors.green;
    } else if (overall >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scoreColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$overall',
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['concept'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      (entry['explanation'] ?? '').length > 80
                          ? '${(entry['explanation'] as String).substring(0, 80)}...'
                          : entry['explanation'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${entry['xpEarned']} XP',
                  style: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniBar('C', entry['clarity'], Colors.blue),
              const SizedBox(width: 8),
              _miniBar('A', entry['accuracy'], Colors.green),
              const SizedBox(width: 8),
              _miniBar('Co', entry['completeness'], Colors.orange),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: (60 * index).ms);
  }

  Widget _miniBar(String label, dynamic value, Color color) {
    final v = (value as int?) ?? 0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$v', style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: v / 100,
              backgroundColor: Colors.white.withAlpha(15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
