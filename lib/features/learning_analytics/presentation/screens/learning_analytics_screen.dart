import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningAnalyticsScreen extends StatefulWidget {
  const LearningAnalyticsScreen({super.key});

  @override
  State<LearningAnalyticsScreen> createState() =>
      _LearningAnalyticsScreenState();
}

class _LearningAnalyticsScreenState extends State<LearningAnalyticsScreen> {
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('learning_analytics');
    if (raw != null) {
      _analytics = Map<String, dynamic>.from(json.decode(raw));
    } else {
      _analytics = _generateSampleAnalytics();
      await _saveAnalytics();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('learning_analytics', json.encode(_analytics));
  }

  Map<String, dynamic> _generateSampleAnalytics() {
    return {
      'learningStyles': {
        'Visual': 35,
        'Reading': 25,
        'Auditory': 20,
        'Kinesthetic': 20,
      },
      'weaknessHeatmap': {
        'Physics': {
          'Mechanics': 85,
          'Electromagnetism': 45,
          'Optics': 60,
          'Modern Physics': 30,
        },
        'Chemistry': {
          'Organic': 70,
          'Inorganic': 55,
          'Physical Chem': 40,
          'Analytical': 65,
        },
        'Maths': {
          'Calculus': 90,
          'Algebra': 75,
          'Geometry': 50,
          'Trigonometry': 60,
        },
        'Biology': {
          'Genetics': 80,
          'Ecology': 45,
          'Human Physiology': 70,
          'Cell Biology': 55,
        },
      },
      'performancePrediction': [
        {'month': 'Jan', 'actual': 72, 'predicted': 70},
        {'month': 'Feb', 'actual': 75, 'predicted': 73},
        {'month': 'Mar', 'actual': 78, 'predicted': 76},
        {'month': 'Apr', 'actual': 80, 'predicted': 79},
        {'month': 'May', 'actual': null, 'predicted': 82},
        {'month': 'Jun', 'actual': null, 'predicted': 85},
        {'month': 'Jul', 'actual': null, 'predicted': 88},
      ],
      'efficiency': {
        'hoursStudied': 142,
        'conceptsLearned': 89,
        'efficiencyScore': 78,
      },
      'trajectory': {
        'currentScore': 78,
        'in30Days': 83,
        'in60Days': 87,
        'in90Days': 91,
      },
      'totalStudyHours': 142,
      'totalConcepts': 89,
      'averageMastery': 72,
      'streakDays': 14,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Learning Analytics',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(),
                const SizedBox(height: 24),
                _buildSectionTitle('Learning DNA Report'),
                const SizedBox(height: 12),
                _buildLearningDNA(),
                const SizedBox(height: 24),
                _buildSectionTitle('Weakness Heatmap'),
                const SizedBox(height: 12),
                _buildWeaknessHeatmap(),
                const SizedBox(height: 24),
                _buildSectionTitle('Performance Prediction'),
                const SizedBox(height: 12),
                _buildPerformanceChart(),
                const SizedBox(height: 24),
                _buildSectionTitle('Study Efficiency'),
                const SizedBox(height: 12),
                _buildEfficiencyCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Improvement Trajectory'),
                const SizedBox(height: 12),
                _buildTrajectory(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _summaryCard('Hours', '${_analytics['totalStudyHours'] ?? 0}',
            Icons.schedule, Colors.blue),
        const SizedBox(width: 12),
        _summaryCard('Concepts', '${_analytics['totalConcepts'] ?? 0}',
            Icons.lightbulb, Colors.amber),
        const SizedBox(width: 12),
        _summaryCard('Mastery', '${_analytics['averageMastery'] ?? 0}%',
            Icons.trending_up, Colors.green),
        const SizedBox(width: 12),
        _summaryCard('Streak', '${_analytics['streakDays'] ?? 0}d',
            Icons.local_fire_department, Colors.orangeAccent),
      ],
    ).animate().fade().slideY(begin: -0.1);
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ));
  }

  Widget _buildLearningDNA() {
    final styles = Map<String, dynamic>.from(
        _analytics['learningStyles'] ?? {});
    final colors = {
      'Visual': Colors.blue,
      'Reading': Colors.green,
      'Auditory': Colors.amber,
      'Kinesthetic': Colors.deepPurpleAccent,
    };
    final icons = {
      'Visual': Icons.visibility,
      'Reading': Icons.menu_book,
      'Auditory': Icons.headphones,
      'Kinesthetic': Icons.directions_run,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _PieChartPainter(styles, colors),
              size: const Size(180, 180),
            ),
          ).animate().scale(delay: 200.ms),
          const SizedBox(height: 20),
          ...styles.entries.map((entry) {
            final color = colors[entry.key] ?? Colors.white;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icons[entry.key], color: color, size: 20),
                  const SizedBox(width: 10),
                  SizedBox(
                      width: 90,
                      child: Text(entry.key,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (entry.value as int) / 100,
                        backgroundColor: Colors.white.withAlpha(15),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                      width: 36,
                      child: Text('${entry.value}%',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeaknessHeatmap() {
    final heatmap = Map<String, dynamic>.from(
        _analytics['weaknessHeatmap'] ?? {});

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: heatmap.entries.map((subjectEntry) {
          final chapters = Map<String, dynamic>.from(subjectEntry.value);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subjectEntry.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chapters.entries.map((chapter) {
                    final mastery = chapter.value as int;
                    final color = _masteryColor(mastery);
                    return Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withAlpha(60)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$mastery%',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chapter.key,
                            style: TextStyle(
                              color: Colors.white.withAlpha(140),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _masteryColor(int mastery) {
    if (mastery >= 80) return Colors.green;
    if (mastery >= 60) return Colors.blue;
    if (mastery >= 40) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _buildPerformanceChart() {
    final data = List<Map<String, dynamic>>.from(
        _analytics['performancePrediction'] ?? []);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomPaint(
        painter: _LineChartPainter(data),
        size: Size.infinite,
      ),
    ).animate().fade(delay: 300.ms);
  }

  Widget _buildEfficiencyCard() {
    final eff = Map<String, dynamic>.from(
        _analytics['efficiency'] ?? {});
    final score = eff['efficiencyScore'] ?? 0;
    final hours = eff['hoursStudied'] ?? 0;
    final concepts = eff['conceptsLearned'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withAlpha(15),
                    valueColor: const AlwaysStoppedAnimation(
                        Colors.deepPurpleAccent),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: const TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        )),
                    const Text('Score',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _effStat('Hours', '$hours', Colors.blue),
              _effStat('Concepts', '$concepts', Colors.amber),
              _effStat(
                  'Per Hour',
                  hours > 0
                      ? (concepts / hours).toStringAsFixed(1)
                      : '0',
                  Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _effStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(100), fontSize: 12)),
      ],
    );
  }

  Widget _buildTrajectory() {
    final traj = Map<String, dynamic>.from(
        _analytics['trajectory'] ?? {});
    final current = traj['currentScore'] ?? 0;
    final d30 = traj['in30Days'] ?? 0;
    final d60 = traj['in60Days'] ?? 0;
    final d90 = traj['in90Days'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _trajectoryRow('Now', current, Colors.white, true),
          const SizedBox(height: 4),
          _trajectoryArrow(),
          _trajectoryRow('+30 Days', d30, Colors.blue, false),
          const SizedBox(height: 4),
          _trajectoryArrow(),
          _trajectoryRow('+60 Days', d60, Colors.green, false),
          const SizedBox(height: 4),
          _trajectoryArrow(),
          _trajectoryRow('+90 Days', d90, Colors.deepPurpleAccent, false),
        ],
      ),
    );
  }

  Widget _trajectoryRow(
      String label, int score, Color color, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withAlpha(20)
            : color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: isCurrent ? Border.all(color: color.withAlpha(40)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white70,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                )),
          ),
          Text('$score%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              )),
        ],
      ),
    );
  }

  Widget _trajectoryArrow() {
    return Icon(Icons.arrow_downward,
        color: Colors.white.withAlpha(40), size: 16);
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final Map<String, Color> colors;

  _PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final total = data.values.fold<int>(0, (sum, v) => sum + (v as int));

    double startAngle = -pi / 2;
    for (final entry in data.entries) {
      final sweep = (entry.value as int) / total * 2 * pi;
      final paint = Paint()
        ..color = colors[entry.key] ?? Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    final innerPaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawCircle(center, radius * 0.55, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final padding = const EdgeInsets.all(20);
    final chartWidth = size.width - padding.horizontal;
    final chartHeight = size.height - padding.vertical;

    final actualPaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final predictedPaint = Paint()
      ..color = Colors.deepPurpleAccent.withAlpha(100)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeCap = StrokeCap.round;

    final actualPoints = <Offset>[];
    final predictedPoints = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = padding.left + (i / (data.length - 1)) * chartWidth;
      final actual = data[i]['actual'] as int?;
      final predicted = data[i]['predicted'] as int?;

      if (actual != null) {
        final y = padding.top + (1 - actual / 100) * chartHeight;
        actualPoints.add(Offset(x, y));
      }
      if (predicted != null) {
        final y = padding.top + (1 - predicted / 100) * chartHeight;
        predictedPoints.add(Offset(x, y));
      }
    }

    if (predictedPoints.length > 1) {
      final path = Path();
      path.moveTo(predictedPoints.first.dx, predictedPoints.first.dy);
      for (int i = 1; i < predictedPoints.length; i++) {
        path.lineTo(predictedPoints[i].dx, predictedPoints[i].dy);
      }
      canvas.drawPath(path, predictedPaint);
    }

    if (actualPoints.length > 1) {
      final path = Path();
      path.moveTo(actualPoints.first.dx, actualPoints.first.dy);
      for (int i = 1; i < actualPoints.length; i++) {
        path.lineTo(actualPoints[i].dx, actualPoints[i].dy);
      }
      canvas.drawPath(path, actualPaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final p in actualPoints) {
      dotPaint.color = Colors.deepPurpleAccent;
      canvas.drawCircle(p, 4, dotPaint);
    }
    for (final p in predictedPoints) {
      dotPaint.color = Colors.deepPurpleAccent.withAlpha(100);
      canvas.drawCircle(p, 3, dotPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < data.length; i++) {
      final x = padding.left + (i / (data.length - 1)) * chartWidth;
      textPainter.text = TextSpan(
        text: data[i]['month'] ?? '',
        style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2,
              size.height - padding.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
