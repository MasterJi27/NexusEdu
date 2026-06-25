import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionPaperGenScreen extends StatefulWidget {
  const QuestionPaperGenScreen({super.key});

  @override
  State<QuestionPaperGenScreen> createState() => _QuestionPaperGenScreenState();
}

class _QuestionPaperGenScreenState extends State<QuestionPaperGenScreen> {
  String _selectedBoard = 'CBSE';
  String _selectedClass = '12';
  String _selectedSubject = 'Physics';
  String _totalMarks = '70';
  String _timeAllowed = '3 Hours';
  int _sectionACount = 10;
  int _sectionBCount = 8;
  int _sectionCCount = 5;
  bool _isLoading = false;
  String _generatedPaper = '';
  List<Map<String, dynamic>> _savedPapers = [];

  final Map<String, List<String>> _subjectsByBoard = {
    'CBSE': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English', 'Hindi'],
    'ICSE': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English', 'Hindi'],
    'State Board': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English'],
  };

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('generated_papers') ?? [];
    setState(() {
      _savedPapers = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  int get _computedTotalMarks =>
      _sectionACount * 1 + _sectionBCount * 3 + _sectionCCount * 5;

  Future<void> _generatePaper() async {
    setState(() {
      _isLoading = true;
      _generatedPaper = '';
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Create a $_selectedBoard Class $_selectedClass $_selectedSubject '
              'question paper. Total Marks: $_computedTotalMarks, Time: $_timeAllowed. '
              'Format:\n'
              'Section A (1-mark questions): $_sectionACount questions\n'
              'Section B (3-mark questions): $_sectionBCount questions\n'
              'Section C (5-mark questions): $_sectionCCount questions\n'
              'Include proper headings, marks per question, and clear numbering. '
              'Add instructions at the top.',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _generatedPaper = result;
    });

    _savedPapers.insert(0, {
      'board': _selectedBoard,
      'class': _selectedClass,
      'subject': _selectedSubject,
      'marks': _computedTotalMarks.toString(),
      'time': _timeAllowed,
      'content': _generatedPaper,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedPapers.length > 50) _savedPapers.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'generated_papers',
      _savedPapers.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Question Paper Generator',
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
              (val) => setState(() => _selectedSubject = val!),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Total Marks',
              ['50', '70', '80', '100'],
              _totalMarks,
              (val) => setState(() => _totalMarks = val!),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Time',
              ['2 Hours', '3 Hours', '3.5 Hours'],
              _timeAllowed,
              (val) => setState(() => _timeAllowed = val!),
            ),
            const SizedBox(height: 16),
            _buildBlueprintCard(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generatePaper,
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
                  _isLoading ? 'Generating Paper...' : 'Generate Paper',
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
            if (_generatedPaper.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildPaperCard(),
            ],
            if (_savedPapers.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Generated Papers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedPapers.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedPapers[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlueprintCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paper Blueprint',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildBlueprintRow('Section A', '1-mark', _sectionACount, (val) {
            setState(() => _sectionACount = val);
          }),
          const SizedBox(height: 8),
          _buildBlueprintRow('Section B', '3-mark', _sectionBCount, (val) {
            setState(() => _sectionBCount = val);
          }),
          const SizedBox(height: 8),
          _buildBlueprintRow('Section C', '5-mark', _sectionCCount, (val) {
            setState(() => _sectionCCount = val);
          }),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Computed Total',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_computedTotalMarks marks',
                style: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildBlueprintRow(
    String section,
    String markType,
    int count,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$section ($markType)',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${count * (markType == '1-mark' ? 1 : markType == '3-mark' ? 3 : 5)} marks',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, color: Colors.deepPurpleAccent, size: 18),
                onPressed: count > 0 ? () => onChanged(count - 1) : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.deepPurpleAccent, size: 18),
                  onPressed: count < 30 ? () => onChanged(count + 1) : null,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
            ],
          ),
        ),
      ],
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

  Widget _buildPaperCard() {
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
              const Icon(Icons.description, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedSubject - Class $_selectedClass',
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
            _generatedPaper,
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
          Icon(Icons.quiz, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
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
                  '${item['marks']} marks | ${item['time']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedPapers.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'generated_papers',
                    _savedPapers.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
