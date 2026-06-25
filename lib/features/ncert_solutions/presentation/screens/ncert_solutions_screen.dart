import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NcertSolutionsScreen extends StatefulWidget {
  const NcertSolutionsScreen({super.key});

  @override
  State<NcertSolutionsScreen> createState() => _NcertSolutionsScreenState();
}

class _NcertSolutionsScreenState extends State<NcertSolutionsScreen> {
  String _selectedClass = '10';
  String _selectedSubject = 'Physics';
  String _selectedChapter = '';
  bool _isLoading = false;
  String _solutions = '';
  List<Map<String, dynamic>> _recentSolutions = [];

  final Map<String, List<String>> _chaptersBySubject = {
    'Physics': [
      'Light - Reflection and Refraction',
      'Human Eye and Colourful World',
      'Electricity',
      'Magnetic Effects of Electric Current',
      'Sources of Energy',
      'Our Environment',
    ],
    'Chemistry': [
      'Chemical Reactions and Equations',
      'Acids, Bases and Salts',
      'Metals and Non-metals',
      'Carbon and its Compounds',
      'Periodic Classification of Elements',
    ],
    'Biology': [
      'Life Processes',
      'Control and Coordination',
      'How do Organisms Reproduce?',
      'Heredity and Evolution',
      'Our Environment',
    ],
    'Maths': [
      'Real Numbers',
      'Polynomials',
      'Pair of Linear Equations in Two Variables',
      'Quadratic Equations',
      'Arithmetic Progressions',
      'Triangles',
      'Coordinate Geometry',
      'Introduction to Trigonometry',
      'Circles',
      'Constructions',
      'Areas Related to Circles',
      'Surface Areas and Volumes',
      'Statistics',
      'Probability',
    ],
    'English': [
      'A Letter to God',
      'Nelson Mandela: Long Walk to Freedom',
      'Two Stories about Flying',
      'From the Diary of Anne Frank',
      'The Hundred Dresses-I',
      'Glimpses of India',
      'Mijbil the Otter',
      'Madam Rides the Bus',
      'The Sermon at Benares',
      'The Proposal',
    ],
    'Hindi': [
      'शुभकामनाओं के प्रसंग',
      'स्मृति',
      'साना - साना हाथ जोड़ना',
      'आत्मकथ्य',
      'उत्साह और सहयोग',
      'राम विलास पाठक - एक जीवन',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;
    _loadRecentSolutions();
  }

  Future<void> _loadRecentSolutions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('ncert_solutions') ?? [];
    setState(() {
      _recentSolutions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveRecentSolutions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ncert_solutions',
      _recentSolutions.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _getSolutions() async {
    setState(() {
      _isLoading = true;
      _solutions = '';
    });

    final prompt = "Class $_selectedClass $_selectedSubject: $_selectedChapter. "
        "Provide detailed step-by-step NCERT solutions for all questions in this chapter. "
        "Format with question numbers and clear explanations.";

    final result = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _solutions = result;
    });

    _recentSolutions.insert(0, {
      'class': _selectedClass,
      'subject': _selectedSubject,
      'chapter': _selectedChapter,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_recentSolutions.length > 20) _recentSolutions.removeLast();
    _saveRecentSolutions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'NCERT Solutions',
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
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSelectorsCard(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _getSolutions,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.tealAccent.withAlpha(200),
                  foregroundColor: Colors.black,
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
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Generating Solutions...' : 'Get Solutions',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_solutions.isNotEmpty) _buildSolutionsCard(),
            if (_recentSolutions.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Recent Solutions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_recentSolutions.length, (i) {
                final sol = _recentSolutions[i];
                return _buildRecentItem(sol, i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: Colors.tealAccent, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NCERT Solutions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Step-by-step solutions for Classes 6-12',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.06);
  }

  Widget _buildSelectorsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown('Class', _selectedClass,
              List.generate(7, (i) => (i + 6).toString()), (val) {
            setState(() {
              _selectedClass = val!;
            });
          }),
          const SizedBox(height: 12),
          _buildDropdown(
            'Subject',
            _selectedSubject,
            _chaptersBySubject.keys.toList(),
            (val) {
              setState(() {
                _selectedSubject = val!;
                _selectedChapter = _chaptersBySubject[_selectedSubject]!.first;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            'Chapter',
            _selectedChapter,
            _chaptersBySubject[_selectedSubject]!,
            (val) => setState(() => _selectedChapter = val!),
          ),
        ],
      ),
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
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
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSolutionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article, color: Colors.tealAccent, size: 20),
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
            _solutions,
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

  Widget _buildRecentItem(Map<String, dynamic> sol, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: Colors.white.withAlpha(80), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class ${sol['class']} - ${sol['subject']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sol['chapter'] ?? '',
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
              setState(() => _recentSolutions.removeAt(index));
              _saveRecentSolutions();
            },
          ),
        ],
      ),
    );
  }
}
