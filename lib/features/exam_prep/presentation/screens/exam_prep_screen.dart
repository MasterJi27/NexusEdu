import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  String _selectedBoard = 'CBSE';
  String _selectedClass = '12';
  String _selectedSubject = 'Physics';
  bool _isLoading = false;
  String _generatedContent = '';
  String _activeMode = '';
  List<Map<String, dynamic>> _savedAnalysis = [];

  final Map<String, List<String>> _subjectsByBoard = {
    'CBSE': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English', 'Hindi'],
    'ICSE': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English', 'Hindi'],
    'State Board': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English'],
  };

  static final Map<String, Map<String, double>> _chapterWeightage = {
    'Physics': {
      'Electrostatics': 8.0,
      'Current Electricity': 7.0,
      'Magnetic Effects of Current': 7.0,
      'Electromagnetic Induction': 6.0,
      'Optics': 10.0,
      'Dual Nature of Matter': 4.0,
      'Atoms & Nuclei': 5.0,
      'Semiconductor Devices': 4.0,
    },
    'Chemistry': {
      'Solid State': 4.0,
      'Solutions': 5.0,
      'Electrochemistry': 4.0,
      'Chemical Kinetics': 5.0,
      'Surface Chemistry': 3.0,
      'p-Block Elements': 8.0,
      'd-Block Elements': 4.0,
      'Coordination Compounds': 5.0,
      'Haloalkanes & Haloarenes': 4.0,
      'Alcohols, Phenols & Ethers': 4.0,
      'Aldehydes, Ketones & Carboxylic Acids': 6.0,
      'Amines': 3.0,
      'Biomolecules': 4.0,
      'Polymers': 3.0,
      'Chemistry in Everyday Life': 3.0,
    },
    'Biology': {
      'Reproduction in Organisms': 6.0,
      'Sexual Reproduction in Flowering Plants': 5.0,
      'Human Reproduction': 6.0,
      'Reproductive Health': 3.0,
      'Principles of Inheritance': 7.0,
      'Molecular Basis of Inheritance': 8.0,
      'Evolution': 4.0,
      'Human Health & Disease': 5.0,
      'Microbes in Human Welfare': 3.0,
      'Biotechnology Principles': 5.0,
      'Biotechnology Applications': 5.0,
      'Organisms & Populations': 4.0,
      'Ecosystem': 5.0,
      'Biodiversity & Conservation': 4.0,
    },
    'Maths': {
      'Relations & Functions': 8.0,
      'Inverse Trigonometric Functions': 4.0,
      'Matrices': 7.0,
      'Determinants': 6.0,
      'Continuity & Differentiability': 8.0,
      'Applications of Derivatives': 8.0,
      'Integrals': 12.0,
      'Applications of Integrals': 5.0,
      'Differential Equations': 8.0,
      'Vector Algebra': 6.0,
      'Three Dimensional Geometry': 8.0,
      'Linear Programming': 5.0,
      'Probability': 5.0,
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedSubject = _subjectsByBoard[_selectedBoard]!.first;
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('exam_prep_data') ?? [];
    setState(() {
      _savedAnalysis = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'exam_prep_data',
      _savedAnalysis.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _generateContent(String mode) async {
    setState(() {
      _isLoading = true;
      _generatedContent = '';
      _activeMode = mode;
    });

    String prompt;
    switch (mode) {
      case 'predicted':
        prompt = "For $_selectedBoard Class $_selectedClass $_selectedSubject: "
            "Generate 15 most likely exam questions based on recent trends. "
            "Include expected marks and difficulty level for each.";
        break;
      case 'analysis':
        prompt = "For $_selectedBoard Class $_selectedClass $_selectedSubject: "
            "Analyze previous year question patterns. Give chapter-wise weightage, "
            "recurring topics, and marks distribution trends for last 5 years.";
        break;
      default:
        prompt = "For $_selectedBoard Class $_selectedClass $_selectedSubject: "
            "Provide comprehensive exam preparation tips, important formulas, "
            "and key concepts to focus on.";
    }

    final result = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _generatedContent = result;
    });

    _savedAnalysis.insert(0, {
      'board': _selectedBoard,
      'class': _selectedClass,
      'subject': _selectedSubject,
      'mode': mode,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedAnalysis.length > 20) _savedAnalysis.removeLast();
    _saveAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Exam Prep',
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
            _buildBoardSelector(),
            const SizedBox(height: 12),
            _buildClassSelector(),
            const SizedBox(height: 12),
            _buildSubjectSelector(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildWeightageCard(),
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(color: Colors.orangeAccent),
              ),
            ],
            if (_generatedContent.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildContentCard(),
            ],
            if (_savedAnalysis.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Recent Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedAnalysis.length.clamp(0, 8), (i) {
                return _buildSavedItem(_savedAnalysis[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSelector() {
    return _buildSelectorRow(
      'Board',
      ['CBSE', 'ICSE', 'State Board'],
      _selectedBoard,
      (val) => setState(() {
        _selectedBoard = val!;
        _selectedSubject = _subjectsByBoard[_selectedBoard]!.first;
      }),
    );
  }

  Widget _buildClassSelector() {
    return _buildSelectorRow(
      'Class',
      ['9', '10', '11', '12'],
      _selectedClass,
      (val) => setState(() => _selectedClass = val!),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildSelectorRow(
      'Subject',
      _subjectsByBoard[_selectedBoard]!,
      _selectedSubject,
      (val) => setState(() => _selectedSubject = val!),
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
                        ? Colors.orangeAccent.withAlpha(40)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.orangeAccent
                          : Colors.white.withAlpha(15),
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.orangeAccent
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Predicted Questions',
            Icons.auto_awesome,
            Colors.deepPurpleAccent,
            () => _generateContent('predicted'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            'Previous Year Analysis',
            Icons.analytics,
            Colors.orangeAccent,
            () => _generateContent('analysis'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightageCard() {
    final chapters = _chapterWeightage[_selectedSubject];
    if (chapters == null) return const SizedBox.shrink();
    final maxWeight = chapters.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Chapter Weightage - $_selectedSubject',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...chapters.entries.map((e) {
            final fraction = e.value / maxWeight;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${e.value.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.white.withAlpha(15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      e.value >= 8
                          ? Colors.redAccent
                          : e.value >= 5
                              ? Colors.orangeAccent
                              : Colors.greenAccent,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade(delay: 100.ms);
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
              Icon(
                _activeMode == 'predicted' ? Icons.auto_awesome : Icons.analytics,
                color: Colors.deepPurpleAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activeMode == 'predicted'
                      ? 'Predicted Questions'
                      : 'Previous Year Analysis',
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
          Icon(Icons.history, color: Colors.white.withAlpha(80), size: 18),
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
                  item['mode'] == 'predicted' ? 'Predicted Questions' : 'Year Analysis',
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
              setState(() => _savedAnalysis.removeAt(index));
              _saveAnalysis();
            },
          ),
        ],
      ),
    );
  }
}
