import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningDnaScreen extends StatefulWidget {
  const LearningDnaScreen({super.key});

  @override
  State<LearningDnaScreen> createState() => _LearningDnaScreenState();
}

class _LearningDnaScreenState extends State<LearningDnaScreen> {
  bool _isLoading = true;

  String _preferredStudyTime = 'Morning';
  Map<String, double> _learningStyles = {
    'Visual': 0,
    'Reading': 0,
    'Auditory': 0,
    'Kinesthetic': 0,
  };
  double _attentionSpan = 0;
  double _optimalSessionLength = 0;
  List<String> _recommendations = [];
  String _dnaSummary = '';

  @override
  void initState() {
    super.initState();
    _analyzeLearningDna();
  }

  Future<void> _analyzeLearningDna() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final studyDataRaw = prefs.getStringList('study_sessions') ?? [];
    final List<Map<String, dynamic>> studyData = studyDataRaw
        .map((e) => Map<String, dynamic>.from(json.decode(e)))
        .toList();

    if (studyData.isEmpty) {
      _generateSyntheticData();
    } else {
      _analyzeFromData(studyData);
    }

    await _fetchAiInsights();
    await _saveDna();
    setState(() => _isLoading = false);
  }

  void _generateSyntheticData() {
    final random = Random();
    _preferredStudyTime = ['Morning', 'Afternoon', 'Evening', 'Night'][random.nextInt(4)];
    _learningStyles = {
      'Visual': 25 + random.nextDouble() * 30,
      'Reading': 20 + random.nextDouble() * 25,
      'Auditory': 15 + random.nextDouble() * 25,
      'Kinesthetic': 10 + random.nextDouble() * 20,
    };
    final total = _learningStyles.values.reduce((a, b) => a + b);
    _learningStyles = _learningStyles.map((k, v) => MapEntry(k, (v / total) * 100));
    _attentionSpan = 20 + random.nextDouble() * 40;
    _optimalSessionLength = 25 + random.nextDouble() * 35;
    _recommendations = [
      'Use visual aids like diagrams and charts for better retention',
      'Study in 30-minute focused blocks with 5-minute breaks',
      'You learn best in the $_preferredStudyTime — schedule key subjects then',
      'Incorporate active recall and flashcards into your routine',
    ];
    _dnaSummary = 'Your learning DNA shows a ${_learningStyles.entries.reduce((a, b) => a.value > b.value ? a : b).key.toLowerCase()} learner '
        'who thrives during $_preferredStudyTime sessions.';
  }

  void _analyzeFromData(List<Map<String, dynamic>> data) {
    final hours = <int, double>{};
    for (final session in data) {
      final hour = session['hour'] as int? ?? 12;
      final performance = (session['performance'] as num?)?.toDouble() ?? 50.0;
      hours[hour] = (hours[hour] ?? 0) + performance;
    }
    if (hours.isNotEmpty) {
      final bestHour = hours.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      if (bestHour >= 5 && bestHour < 12) _preferredStudyTime = 'Morning';
      else if (bestHour >= 12 && bestHour < 17) _preferredStudyTime = 'Afternoon';
      else if (bestHour >= 17 && bestHour < 21) _preferredStudyTime = 'Evening';
      else _preferredStudyTime = 'Night';
    }
    _learningStyles = {
      'Visual': 30 + Random().nextDouble() * 20,
      'Reading': 20 + Random().nextDouble() * 20,
      'Auditory': 15 + Random().nextDouble() * 20,
      'Kinesthetic': 10 + Random().nextDouble() * 20,
    };
    final total = _learningStyles.values.reduce((a, b) => a + b);
    _learningStyles = _learningStyles.map((k, v) => MapEntry(k, (v / total) * 100));
    _attentionSpan = LocalComputation.mean(data.map((e) => (e['duration'] as num?)?.toDouble() ?? 30.0).toList());
    _optimalSessionLength = (_attentionSpan * 1.2).clamp(20, 90);
  }

  Future<void> _fetchAiInsights() async {
    try {
      final response = await AiAgentService.callAgent('custom', {
        'prompt': 'Analyze learning DNA:\n'
            'Preferred time: $_preferredStudyTime\n'
            'Learning styles: $_learningStyles\n'
            'Attention span: ${_attentionSpan.toStringAsFixed(0)} min\n'
            'Provide 4 personalized study recommendations (one per line, start with dash).',
      });
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length >= 3) {
        _recommendations = lines.map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()).toList();
      }
    } catch (_) {}
    _dnaSummary = _dnaSummary.isEmpty
        ? 'You are a ${_learningStyles.entries.reduce((a, b) => a.value > b.value ? a : b).key} learner '
            'who studies best in the $_preferredStudyTime.'
        : _dnaSummary;
  }

  Future<void> _saveDna() async {
    final prefs = await SharedPreferences.getInstance();
    final dna = {
      'preferredStudyTime': _preferredStudyTime,
      'learningStyles': _learningStyles,
      'attentionSpan': _attentionSpan,
      'optimalSessionLength': _optimalSessionLength,
      'recommendations': _recommendations,
      'summary': _dnaSummary,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('learning_dna', json.encode(dna));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Learning DNA Decoder', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  _buildDnaSummary(),
                  const SizedBox(height: 20),
                  _buildDnaHelix(),
                  const SizedBox(height: 20),
                  _buildLearningStyles(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildRecommendations(),
                ],
              ),
            ),
    );
  }

  Widget _buildDnaSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Text(_dnaSummary, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.5)),
    ).animate().fade();
  }

  Widget _buildDnaHelix() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 200),
        painter: _DnaHelixPainter(
          attentionSpan: _attentionSpan,
          learningStyles: _learningStyles,
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildLearningStyles() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Learning Style Breakdown',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ..._learningStyles.entries.map((entry) {
            final colors = {
              'Visual': Colors.blueAccent,
              'Reading': Colors.greenAccent,
              'Auditory': Colors.orangeAccent,
              'Kinesthetic': Colors.pinkAccent,
            };
            final color = colors[entry.key] ?? Colors.deepPurpleAccent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                      Text('${entry.value.toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white.withAlpha(15),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Attention Span', '${_attentionSpan.toStringAsFixed(0)} min', Icons.timer),
        const SizedBox(width: 12),
        _buildStatCard('Optimal Session', '${_optimalSessionLength.toStringAsFixed(0)} min', Icons.schedule),
        const SizedBox(width: 12),
        _buildStatCard('Best Time', _preferredStudyTime, Icons.wb_sunny),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurpleAccent, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    ).animate().fade();
  }

  Widget _buildRecommendations() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personalized Recommendations',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amberAccent.withAlpha(200), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fade();
  }
}

class _DnaHelixPainter extends CustomPainter {
  final double attentionSpan;
  final Map<String, double> learningStyles;

  _DnaHelixPainter({required this.attentionSpan, required this.learningStyles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..strokeWidth = 2.5..style = PaintingStyle.stroke;

    for (int strand = 0; strand < 2; strand++) {
      final offset = strand == 0 ? 0.0 : pi;
      final color = strand == 0 ? Colors.deepPurpleAccent : Colors.purpleAccent.withAlpha(150);
      paint.color = color;

      final path = Path();
      for (double i = 0; i <= size.width; i += 2) {
        final t = (i / size.width) * 3 * pi;
        final y = center.dy + sin(t + offset) * (size.height * 0.3);
        if (i == 0) {
          path.moveTo(i, y);
        } else {
          path.lineTo(i, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    for (double i = 0; i <= size.width; i += size.width / 12) {
      final t = (i / size.width) * 3 * pi;
      final y1 = center.dy + sin(t) * (size.height * 0.3);
      final y2 = center.dy + sin(t + pi) * (size.height * 0.3);
      final dist = (y1 - y2).abs();
      if (dist < size.height * 0.4) {
        final colors = [Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.pinkAccent];
        paint
          ..color = colors[(i ~/ (size.width / 12)) % colors.length].withAlpha(120)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(i, y1), Offset(i, y2), paint);
      }
    }

    final centerPaint = Paint()..color = Colors.deepPurpleAccent;
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
