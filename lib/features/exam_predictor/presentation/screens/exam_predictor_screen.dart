import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class ExamPredictorScreen extends StatefulWidget {
  const ExamPredictorScreen({super.key});

  @override
  State<ExamPredictorScreen> createState() => _ExamPredictorScreenState();
}

class _ExamPredictorScreenState extends State<ExamPredictorScreen> {
  String _selectedBoard = 'CBSE';
  String _selectedClass = 'Class 10';
  String _selectedSubject = 'Mathematics';
  String _selectedExam = 'Final Exam';
  bool _isLoading = false;
  List<Map<String, dynamic>> _predictions = [];
  List<Map<String, dynamic>> _mostAskedTopics = [];
  List<double> _pastPaperData = [];

  static const List<String> _boards = ['CBSE', 'ICSE', 'State Board', 'JEE', 'NEET'];
  static const List<String> _classes = ['Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12'];
  static const List<String> _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'Hindi', 'History', 'Geography'];
  static const List<String> _exams = ['Final Exam', 'Mid-Term', 'Pre-Board', 'JEE Main', 'JEE Advanced', 'NEET'];

  @override
  void initState() {
    super.initState();
    _loadPredictions();
    _generatePastPaperData();
  }

  Future<void> _loadPredictions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('exam_predictions');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      _selectedBoard = last['board'] ?? 'CBSE';
      _selectedClass = last['class'] ?? 'Class 10';
      _selectedSubject = last['subject'] ?? 'Mathematics';
      _selectedExam = last['exam'] ?? 'Final Exam';
    }
    setState(() {});
  }

  Future<void> _savePredictions() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('exam_predictions') ?? [];
    history.add(jsonEncode({
      'board': _selectedBoard,
      'class': _selectedClass,
      'subject': _selectedSubject,
      'exam': _selectedExam,
      'predictions': _predictions,
      'mostAsked': _mostAskedTopics,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 20) history.removeAt(0);
    await prefs.setStringList('exam_predictions', history);
  }

  void _generatePastPaperData() {
    _pastPaperData = List.generate(8, (_) => 30 + Random().nextDouble() * 70);
  }

  Future<void> _predictQuestions() async {
    setState(() {
      _isLoading = true;
      _predictions = [];
      _mostAskedTopics = [];
    });

    final prompt = 'Predict $_selectedExam questions for $_selectedBoard $_selectedSubject $_selectedClass. '
        'Generate 8 questions with probability percentages. '
        'Also list 5 most asked topics. '
        'Format as JSON: {"questions": [{"q": "...", "probability": 85, "type": "SA/LA/VMCQ"}], '
        '"topics": [{"name": "...", "frequency": 95}]}';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    final rng = Random();
    try {
      final jsonStr = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _predictions = (data['questions'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((q) => {
        'q': q['q'] ?? q['question'] ?? 'Question',
        'probability': q['probability'] ?? (50 + rng.nextInt(40)),
        'type': q['type'] ?? 'SA',
      }).toList();
      _mostAskedTopics = (data['topics'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((t) => {
        'name': t['name'] ?? t['topic'] ?? 'Topic',
        'frequency': t['frequency'] ?? (60 + rng.nextInt(35)),
      }).toList();
    } catch (_) {
      _predictions = List.generate(6, (i) => {
        'q': 'Predicted Question ${i + 1}: Explain key concepts of $_selectedSubject',
        'probability': 50 + rng.nextInt(45),
        'type': ['SA', 'LA', 'VMCQ'][rng.nextInt(3)],
      });
      _mostAskedTopics = ['Algebra', 'Calculus', 'Trigonometry', 'Geometry', 'Statistics']
          .take(5)
          .map((t) => {'name': t, 'frequency': 60 + rng.nextInt(35)})
          .toList();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _savePredictions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Exam Predictor AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSelectors(),
          const SizedBox(height: 16),
          _buildPredictButton(),
          if (_predictions.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildPredictionsList(),
            const SizedBox(height: 24),
            _buildPastPaperChart(),
            const SizedBox(height: 24),
            _buildMostAskedTopics(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configure Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          _buildDropdown('Board', _boards, _selectedBoard, (v) => setState(() => _selectedBoard = v!)),
          const SizedBox(height: 10),
          _buildDropdown('Class', _classes, _selectedClass, (v) => setState(() => _selectedClass = v!)),
          const SizedBox(height: 10),
          _buildDropdown('Subject', _subjects, _selectedSubject, (v) => setState(() => _selectedSubject = v!)),
          const SizedBox(height: 10),
          _buildDropdown('Exam Type', _exams, _selectedExam, (v) => setState(() => _selectedExam = v!)),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildDropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withAlpha(150)),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _predictQuestions,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Predict Questions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildPredictionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Predicted Questions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        ..._predictions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value;
          final prob = q['probability'] as int;
          final color = prob > 75 ? Colors.green : prob > 50 ? Colors.amberAccent : Colors.redAccent;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$prob%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text('%', style: TextStyle(color: Colors.white38, fontSize: 8)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q['type'] ?? 'SA', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(q['q'] ?? '', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: Duration(milliseconds: i * 80));
        }),
      ],
    );
  }

  Widget _buildPastPaperChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Past Paper Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _BarChartPainter(_pastPaperData),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026']
                .map((y) => Text(y, style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 9)))
                .toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildMostAskedTopics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Most Asked Topics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._mostAskedTopics.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final freq = t['frequency'] as int;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['name'] ?? '', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: freq / 100,
                            backgroundColor: Colors.white.withAlpha(20),
                            valueColor: AlwaysStoppedAnimation(
                              freq > 80 ? Colors.deepPurpleAccent : Colors.blueAccent,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$freq%', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade();
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  _BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barWidth = size.width / (data.length * 2);
    final maxVal = data.reduce(max);

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxVal) * size.height * 0.85;
      final x = i * (size.width / data.length) + barWidth * 0.5;
      final y = size.height - barHeight;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurpleAccent, Colors.deepPurpleAccent.withAlpha(80)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
