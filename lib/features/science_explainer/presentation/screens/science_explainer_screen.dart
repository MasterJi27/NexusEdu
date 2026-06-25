import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScienceExplainerScreen extends StatefulWidget {
  const ScienceExplainerScreen({super.key});

  @override
  State<ScienceExplainerScreen> createState() => _ScienceExplainerScreenState();
}

class _ScienceExplainerScreenState extends State<ScienceExplainerScreen> {
  final TextEditingController _scenarioController = TextEditingController();
  bool _isLoading = false;
  bool _explained = false;

  String _explanation = '';
  String _funFacts = '';
  String _syllabusConnect = '';
  List<Map<String, dynamic>> _pastExplanations = [];

  @override
  void initState() {
    super.initState();
    _loadExplanations();
  }

  @override
  void dispose() {
    _scenarioController.dispose();
    super.dispose();
  }

  Future<void> _loadExplanations() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('science_explanations') ?? [];
    setState(() {
      _pastExplanations = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveExplanation() async {
    final prefs = await SharedPreferences.getInstance();
    final explanations = prefs.getStringList('science_explanations') ?? [];
    explanations.add(json.encode({
      'scenario': _scenarioController.text.trim(),
      'explanation': _explanation,
      'funFacts': _funFacts,
      'syllabusConnect': _syllabusConnect,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (explanations.length > 20) explanations.removeAt(0);
    await prefs.setStringList('science_explanations', explanations);
    _loadExplanations();
  }

  Future<void> _explainScience() async {
    final scenario = _scenarioController.text.trim();
    if (scenario.isEmpty) return;

    setState(() {
      _isLoading = true;
      _explained = false;
    });

    try {
      final result = await AiAgentService.callAgent(
        'concept_explainer',
        {'concept': scenario, 'subject': 'Science'},
      );
      _parseExplanation(result);
    } catch (_) {
      _explanation =
          'This scenario involves fundamental principles of science. '
          'The underlying mechanisms relate to core concepts in physics and chemistry.';
      _funFacts = '1. Science is everywhere in our daily lives.\n'
          '2. Understanding the "why" helps us appreciate nature.';
      _syllabusConnect = 'Related to: Physics (Forces & Motion), Chemistry (Reactions), Biology (Life Processes)';
    }

    setState(() {
      _isLoading = false;
      _explained = true;
    });

    _saveExplanation();
  }

  void _parseExplanation(String response) {
    _explanation = _extractSection(response, 'EXPLANATION:');
    _funFacts = _extractSection(response, 'FACTS:');
    _syllabusConnect = _extractSection(response, 'SYLLABUS:');

    if (_explanation.isEmpty) {
      _explanation = response;
      _funFacts = '';
      _syllabusConnect = '';
    }
  }

  String _extractSection(String text, String header) {
    final idx = text.indexOf(header);
    if (idx == -1) return '';
    final start = idx + header.length;
    final sections = ['EXPLANATION:', 'FACTS:', 'SYLLABUS:'];
    int end = text.length;
    for (final s in sections) {
      if (s == header) continue;
      final sIdx = text.indexOf(s, start);
      if (sIdx != -1 && sIdx < end) end = sIdx;
    }
    return text.substring(start, end).trim();
  }

  void _resetExplainer() {
    setState(() {
      _explained = false;
      _explanation = '';
      _funFacts = '';
      _syllabusConnect = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Science Explainer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_explained)
            IconButton(
              onPressed: _resetExplainer,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _explained ? _buildExplanationView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Understand the Science',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe any object or scenario. AI explains the science behind it.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _scenarioController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'e.g., Why does ice float on water?',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading || _scenarioController.text.trim().isEmpty
                  ? null
                  : _explainScience,
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
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Explaining...' : 'Explain Science',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastExplanations.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Explanations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastExplanations.length.clamp(0, 5), (i) {
              final e = _pastExplanations[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  e['scenario'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ).animate().fade();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildExplanationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
            ),
            child: Text(
              _scenarioController.text.trim(),
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildContentCard(
            'The Science Behind It',
            _explanation,
            Icons.science,
            Colors.deepPurpleAccent,
          ),
          if (_funFacts.isNotEmpty)
            _buildContentCard(
              'Fun Facts',
              _funFacts,
              Icons.lightbulb,
              Colors.amberAccent,
            ),
          if (_syllabusConnect.isNotEmpty)
            _buildContentCard(
              'Syllabus Connection',
              _syllabusConnect,
              Icons.school,
              Colors.tealAccent,
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetExplainer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Explain Something Else',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(
      String title, String content, IconData icon, Color color) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }
}
