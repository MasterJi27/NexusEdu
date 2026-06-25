import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoryLearningScreen extends StatefulWidget {
  const StoryLearningScreen({super.key});

  @override
  State<StoryLearningScreen> createState() => _StoryLearningScreenState();
}

class _StoryLearningScreenState extends State<StoryLearningScreen> {
  String _selectedSubject = 'Physics';
  String _selectedChapter = '';
  bool _isLoading = false;
  String _generatedStory = '';
  List<Map<String, dynamic>> _savedStories = [];

  final Map<String, List<String>> _chaptersBySubject = {
    'Physics': [
      'Newton\'s Laws of Motion',
      'Work, Energy & Power',
      'Gravitation',
      'Properties of Matter',
      'Thermodynamics',
      'Waves & Oscillations',
      'Electrostatics',
      'Current Electricity',
    ],
    'Chemistry': [
      'Atomic Structure',
      'Chemical Bonding',
      'States of Matter',
      'Chemical Kinetics',
      'Equilibrium',
      'Organic Chemistry Basics',
      'Electrochemistry',
      'Coordination Chemistry',
    ],
    'Biology': [
      'Cell Structure',
      'Genetics & Heredity',
      'Evolution',
      'Human Digestive System',
      'Nervous System',
      'Plant Reproduction',
      'Ecology & Environment',
      'Biotechnology',
    ],
    'Maths': [
      'Pythagorean Theorem',
      'Quadratic Equations',
      'Trigonometry Basics',
      'Probability',
      'Matrices & Determinants',
      'Calculus - Limits',
      'Integration Basics',
      'Vector Algebra',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('learning_stories') ?? [];
    setState(() {
      _savedStories = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _createStory() async {
    setState(() {
      _isLoading = true;
      _generatedStory = '';
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Convert the $_selectedSubject chapter "$_selectedChapter" into an '
              'engaging adventure story for students. Use characters, dialogue, '
              'and a narrative arc. Format with chapter breaks, vivid descriptions, '
              'and embed all key concepts naturally into the story. '
              'Make it fun and educational. Include at least 3 chapters.',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generatedStory = result;
    });

    _savedStories.insert(0, {
      'subject': _selectedSubject,
      'chapter': _selectedChapter,
      'content': _generatedStory,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedStories.length > 50) _savedStories.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'learning_stories',
      _savedStories.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Story-Based Learning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectorRow(
              'Subject',
              ['Physics', 'Chemistry', 'Biology', 'Maths'],
              _selectedSubject,
              (val) => setState(() {
                _selectedSubject = val!;
                _selectedChapter =
                    _chaptersBySubject[_selectedSubject]!.first;
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Chapter',
              _chaptersBySubject[_selectedSubject]!,
              _selectedChapter,
              (val) => setState(() => _selectedChapter = val!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _createStory,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(200),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Creating Story...' : 'Create Story',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 30),
              const Center(
                child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
              ),
            ],
            if (_generatedStory.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildStoryCard(),
            ],
            if (_savedStories.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Stories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedStories.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedStories[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      fontSize: 13,
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

  Widget _buildStoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedSubject - $_selectedChapter',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          SelectableText(
            _generatedStory,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildSavedItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_stories, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['subject'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['chapter'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedStories.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'learning_stories',
                    _savedStories.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
