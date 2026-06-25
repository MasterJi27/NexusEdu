import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiTextbookScreen extends StatefulWidget {
  const AiTextbookScreen({super.key});

  @override
  State<AiTextbookScreen> createState() => _AiTextbookScreenState();
}

class _AiTextbookScreenState extends State<AiTextbookScreen> {
  String _selectedBoard = 'CBSE';
  String _selectedClass = '12';
  String _selectedSubject = 'Physics';
  String _selectedTopic = '';
  bool _isLoading = false;
  String _generatedContent = '';
  List<Map<String, dynamic>> _savedTextbooks = [];

  final Map<String, List<String>> _subjectsByBoard = {
    'CBSE': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English', 'Hindi'],
    'ICSE': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English', 'Hindi'],
    'State Board': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English'],
  };

  final Map<String, List<String>> _topicsBySubject = {
    'Physics': [
      'Electrostatics',
      'Current Electricity',
      'Magnetic Effects',
      'Electromagnetic Induction',
      'Optics',
      'Dual Nature of Matter',
      'Atoms & Nuclei',
      'Semiconductor Devices',
    ],
    'Chemistry': [
      'Solid State',
      'Solutions',
      'Electrochemistry',
      'Chemical Kinetics',
      'p-Block Elements',
      'd-Block Elements',
      'Organic Chemistry',
      'Biomolecules',
    ],
    'Biology': [
      'Reproduction',
      'Genetics & Evolution',
      'Human Physiology',
      'Plant Physiology',
      'Ecology',
      'Biotechnology',
      'Cell Biology',
      'Molecular Biology',
    ],
    'Maths': [
      'Calculus',
      'Algebra',
      'Coordinate Geometry',
      'Trigonometry',
      'Vectors',
      'Probability',
      'Matrices',
      'Differential Equations',
    ],
    'English': [
      'Prose',
      'Poetry',
      'Grammar',
      'Writing Skills',
      'Literature',
    ],
    'Hindi': [
      'गद्य',
      'पद्य',
      'व्याकरण',
      'लेखन',
      'साहित्य',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedTopic = _topicsBySubject[_selectedSubject]!.first;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('ai_textbooks') ?? [];
    setState(() {
      _savedTextbooks = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveTextbook() async {
    if (_generatedContent.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _savedTextbooks.insert(0, {
      'board': _selectedBoard,
      'class': _selectedClass,
      'subject': _selectedSubject,
      'topic': _selectedTopic,
      'content': _generatedContent,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedTextbooks.length > 50) _savedTextbooks.removeLast();
    await prefs.setStringList(
      'ai_textbooks',
      _savedTextbooks.map((e) => json.encode(e)).toList(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as note')),
      );
    }
  }

  Future<void> _generateChapter() async {
    setState(() {
      _isLoading = true;
      _generatedContent = '';
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Write a comprehensive textbook chapter on "$_selectedTopic" for '
              '$_selectedBoard Class $_selectedClass $_selectedSubject. '
              'Include: introduction, detailed explanations with examples, '
              'key formulas, diagrams descriptions, practice questions, '
              'and a summary. Format with headers, bullet points, and examples.',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generatedContent = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'AI Textbook Writer',
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
              'Board',
              ['CBSE', 'ICSE', 'State Board'],
              _selectedBoard,
              (val) => setState(() {
                _selectedBoard = val!;
                _selectedSubject = _subjectsByBoard[_selectedBoard]!.first;
                _selectedTopic = _topicsBySubject[_selectedSubject]!.first;
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Class',
              ['9', '10', '11', '12'],
              _selectedClass,
              (val) => setState(() => _selectedClass = val!),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Subject',
              _subjectsByBoard[_selectedBoard]!,
              _selectedSubject,
              (val) => setState(() {
                _selectedSubject = val!;
                _selectedTopic = _topicsBySubject[_selectedSubject]!.first;
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Topic',
              _topicsBySubject[_selectedSubject]!,
              _selectedTopic,
              (val) => setState(() => _selectedTopic = val!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateChapter,
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
                  _isLoading ? 'Generating Chapter...' : 'Generate Chapter',
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
            if (_generatedContent.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildContentCard(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saveTextbook,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.deepPurpleAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.save_alt, color: Colors.deepPurpleAccent),
                  label: const Text(
                    'Save as Note',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (_savedTextbooks.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Textbooks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedTextbooks.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedTextbooks[i], i);
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

  Widget _buildContentCard() {
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
              const Icon(Icons.menu_book, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedSubject - $_selectedTopic',
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
            _generatedContent,
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
          Icon(Icons.book, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['board']} Class ${item['class']} - ${item['subject']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['topic'] ?? '',
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
              setState(() => _savedTextbooks.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'ai_textbooks',
                    _savedTextbooks.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
