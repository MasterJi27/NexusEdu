import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopicMasteryScreen extends StatefulWidget {
  const TopicMasteryScreen({super.key});

  @override
  State<TopicMasteryScreen> createState() => _TopicMasteryScreenState();
}

class _TopicMasteryScreenState extends State<TopicMasteryScreen> {
  String _selectedSubject = 'Physics';
  bool _isLoading = true;

  Map<String, Map<String, double>> _mastery = {};
  List<String> _chapters = [];
  Map<String, List<Map<String, dynamic>>> _testHistory = {};

  final _subjects = ['Physics', 'Chemistry', 'Maths', 'Biology'];

  @override
  void initState() {
    super.initState();
    _loadMastery();
  }

  Future<void> _loadMastery() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('topic_mastery');
    if (saved != null) {
      final decoded = json.decode(saved) as Map<String, dynamic>;
      _mastery = decoded.map((k, v) => MapEntry(k, Map<String, double>.from(v)));
    } else {
      _generateSyntheticData();
    }
    _updateChapters();
    setState(() => _isLoading = false);
  }

  void _generateSyntheticData() {
    final chaptersMap = {
      'Physics': ['Mechanics', 'Thermodynamics', 'Optics', 'Electromagnetism', 'Modern Physics', 'Waves'],
      'Chemistry': ['Organic Chemistry', 'Inorganic Chemistry', 'Physical Chemistry', 'Biochemistry', 'Environmental Chemistry'],
      'Maths': ['Calculus', 'Algebra', 'Trigonometry', 'Coordinate Geometry', 'Probability', 'Matrices'],
      'Biology': ['Cell Biology', 'Genetics', 'Ecology', 'Human Physiology', 'Plant Biology', 'Evolution'],
    };

    for (final subject in _subjects) {
      final chapters = chaptersMap[subject]!;
      for (final chapter in chapters) {
        final key = '${subject}_$chapter';
        _mastery[key] = {'mastery': 20 + (DateTime.now().millisecond % 80).toDouble()};
      }
    }

    for (final subject in _subjects) {
      final chapters = chaptersMap[subject]!;
      _testHistory[subject] = chapters
          .map((c) => {
                'chapter': c,
                'score': (30 + DateTime.now().millisecond % 70).toDouble(),
                'date': DateTime.now().subtract(Duration(days: DateTime.now().millisecond % 30)).toIso8601String(),
              })
          .toList();
    }
  }

  void _updateChapters() {
    final chaptersMap = {
      'Physics': ['Mechanics', 'Thermodynamics', 'Optics', 'Electromagnetism', 'Modern Physics', 'Waves'],
      'Chemistry': ['Organic Chemistry', 'Inorganic Chemistry', 'Physical Chemistry', 'Biochemistry', 'Environmental Chemistry'],
      'Maths': ['Calculus', 'Algebra', 'Trigonometry', 'Coordinate Geometry', 'Probability', 'Matrices'],
      'Biology': ['Cell Biology', 'Genetics', 'Ecology', 'Human Physiology', 'Plant Biology', 'Evolution'],
    };
    _chapters = chaptersMap[_selectedSubject] ?? [];
  }



  void _practiceWeakTopic(String chapter) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting practice session for $chapter...'), backgroundColor: Colors.deepPurpleAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Topic Mastery Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubjectSelector(),
                  const SizedBox(height: 16),
                  _buildMasteryGrid(),
                  const SizedBox(height: 20),
                  _buildPracticeButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSubjectSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subjects.map((s) {
              final isSelected = s == _selectedSubject;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedSubject = s;
                  _updateChapters();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurpleAccent.withAlpha(40) : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(15)),
                  ),
                  child: Text(s, style: TextStyle(
                    color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(150),
                    fontWeight: FontWeight.bold, fontSize: 12,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildMasteryGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$_selectedSubject Mastery', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Tap a chapter for details', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: CustomPaint(
              size: const Size(double.infinity, 220),
              painter: _MasteryHeatmapPainter(chapters: _chapters, mastery: _mastery, subject: _selectedSubject),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.greenAccent, 'Mastered >80%'),
              const SizedBox(width: 16),
              _buildLegend(Colors.amberAccent, 'Learning 50-80%'),
              const SizedBox(width: 16),
              _buildLegend(Colors.redAccent, 'Weak <50%'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10)),
      ],
    );
  }

  Widget _buildPracticeButton() {
    final weakTopics = _chapters.where((c) {
      final key = '${_selectedSubject}_$c';
      return (_mastery[key]?['mastery'] ?? 50) < 50;
    }).toList();

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: weakTopics.isEmpty
            ? null
            : () {
                for (final t in weakTopics.take(3)) {
                  _practiceWeakTopic(t);
                }
              },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.play_arrow),
        label: Text(
          weakTopics.isEmpty ? 'All Topics Mastered!' : 'Practice Weak Topics (${weakTopics.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ).animate().fade();
  }
}

class _MasteryHeatmapPainter extends CustomPainter {
  final List<String> chapters;
  final Map<String, Map<String, double>> mastery;
  final String subject;

  _MasteryHeatmapPainter({required this.chapters, required this.mastery, required this.subject});

  @override
  void paint(Canvas canvas, Size size) {
    if (chapters.isEmpty) return;
    final padding = const EdgeInsets.fromLTRB(10, 10, 10, 10);
    final cellWidth = (size.width - padding.left - padding.right) / 2;
    final cellHeight = (size.height - padding.top - padding.bottom) / (chapters.length / 2).ceil();

    for (int i = 0; i < chapters.length; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final key = '${subject}_${chapters[i]}';
      final masteryVal = mastery[key]?['mastery'] ?? 50;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          padding.left + col * (cellWidth + 8),
          padding.top + row * (cellHeight + 8),
          cellWidth - 4,
          cellHeight - 4,
        ),
        const Radius.circular(10),
      );

      Color cellColor;
      if (masteryVal >= 80) {
        cellColor = Colors.greenAccent.withAlpha((80 + masteryVal * 1.5).toInt().clamp(80, 255));
      } else if (masteryVal >= 50) {
        cellColor = Colors.amberAccent.withAlpha((60 + masteryVal).toInt().clamp(60, 200));
      } else {
        cellColor = Colors.redAccent.withAlpha((50 + masteryVal).toInt().clamp(50, 180));
      }

      canvas.drawRRect(rect, Paint()..color = cellColor);

      final tp = TextPainter(
        text: TextSpan(
          text: chapters[i],
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: cellWidth - 16);
      tp.paint(canvas, Offset(
        padding.left + col * (cellWidth + 8) + 8,
        padding.top + row * (cellHeight + 8) + cellHeight / 2 - tp.height / 2,
      ));

      final pctTp = TextPainter(
        text: TextSpan(
          text: '${masteryVal.toStringAsFixed(0)}%',
          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pctTp.paint(canvas, Offset(
        padding.left + col * (cellWidth + 8) + cellWidth - pctTp.width - 12,
        padding.top + row * (cellHeight + 8) + 8,
      ));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
