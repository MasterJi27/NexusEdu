import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformancePredictorScreen extends StatefulWidget {
  const PerformancePredictorScreen({super.key});

  @override
  State<PerformancePredictorScreen> createState() => _PerformancePredictorScreenState();
}

class _PerformancePredictorScreenState extends State<PerformancePredictorScreen> {
  final Map<String, TextEditingController> _scoreControllers = {};
  final TextEditingController _hoursController = TextEditingController();
  bool _isLoading = false;
  bool _hasResult = false;

  List<Map<String, dynamic>> _predictions = [];
  List<Map<String, dynamic>> _pastPredictions = [];

  final _subjects = ['Physics', 'Chemistry', 'Maths', 'Biology'];
  double _studyHours = 4;

  @override
  void initState() {
    super.initState();
    for (final s in _subjects) {
      _scoreControllers[s] = TextEditingController();
    }
    _loadPastPredictions();
  }

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadPastPredictions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('performance_predictions') ?? [];
    setState(() {
      _pastPredictions = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
  }

  Future<void> _predict() async {
    final scores = <String, double>{};
    for (final entry in _scoreControllers.entries) {
      final val = double.tryParse(entry.value.text.trim());
      if (val == null || val < 0 || val > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter valid score for ${entry.key} (0-100)')),
        );
        return;
      }
      scores[entry.key] = val;
    }

    _studyHours = double.tryParse(_hoursController.text.trim()) ?? 4;
    if (_studyHours <= 0 || _studyHours > 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study hours must be between 0.5 and 16')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final predictions = <Map<String, dynamic>>[];
    for (final entry in scores.entries) {
      final scores30 = LocalComputation.predictPerformance(
        List.generate(7, (i) => entry.value - 10 + Random().nextDouble() * 5),
        30,
      );
      final scores60 = LocalComputation.predictPerformance(
        List.generate(7, (i) => entry.value - 10 + Random().nextDouble() * 5),
        60,
      );
      final scores90 = LocalComputation.predictPerformance(
        List.generate(7, (i) => entry.value - 10 + Random().nextDouble() * 5),
        90,
      );
      predictions.add({
        'subject': entry.key,
        'current': entry.value,
        'in30': scores30,
        'in60': scores60,
        'in90': scores90,
      });
    }

    String aiMessage = '';
    try {
      aiMessage = await AiAgentService.callAgent('prediction', {
        'scores': scores.values.toList(),
        'hours': _studyHours,
        'days_left': 90,
      });
    } catch (_) {}

    final result = {
      'predictions': predictions,
      'hours': _studyHours,
      'aiMessage': aiMessage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _predictions = predictions;
      _isLoading = false;
      _hasResult = true;
    });

    _pastPredictions.insert(0, result);
    if (_pastPredictions.length > 10) _pastPredictions.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'performance_predictions',
      _pastPredictions.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Performance Predictor', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreInputs(),
            const SizedBox(height: 16),
            _buildHoursInput(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _predict,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.show_chart),
                label: Text(_isLoading ? 'Predicting...' : 'Predict', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildPredictionChart(),
              const SizedBox(height: 20),
              _buildPredictionCards(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreInputs() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Scores (%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 12),
          ..._subjects.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _scoreControllers[s],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: s,
                    labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                    hintText: '0-100',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    filled: true,
                    fillColor: Colors.black.withAlpha(30),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              )),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildHoursInput() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Study Hours Plan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 8),
          TextField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'e.g. 4',
              hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
              filled: true,
              fillColor: Colors.black.withAlpha(30),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildPredictionChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(
        size: const Size(double.infinity, 220),
        painter: _PredictionChartPainter(predictions: _predictions),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildPredictionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Predicted Scores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._predictions.map((p) {
          final subject = p['subject'] as String;
          final current = p['current'] as double;
          final in90 = p['in90'] as double;
          final improvement = in90 - current;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${improvement >= 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: improvement >= 0 ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMiniPrediction('30d', p['in30'] as double),
                    const SizedBox(width: 8),
                    _buildMiniPrediction('60d', p['in60'] as double),
                    const SizedBox(width: 8),
                    _buildMiniPrediction('90d', p['in90'] as double),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
          ),
          child: Text(
            'If you study ${_studyHours.toStringAsFixed(0)} hours daily, '
            'your average score will reach ${(_predictions.map((p) => p['in90'] as double).reduce((a, b) => a + b) / _predictions.length).toStringAsFixed(0)}% in 90 days.',
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.5),
          ),
        ),
      ],
    ).animate().fade();
  }

  Widget _buildMiniPrediction(String label, double score) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 10)),
            const SizedBox(height: 4),
            Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: score >= 70 ? Colors.greenAccent : score >= 50 ? Colors.amberAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}

class _PredictionChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> predictions;

  _PredictionChartPainter({required this.predictions});

  @override
  void paint(Canvas canvas, Size size) {
    if (predictions.isEmpty) return;

    final colors = [Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.pinkAccent];
    final paint = Paint()..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    final padding = const EdgeInsets.fromLTRB(40, 20, 20, 30);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    final gridPaint = Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + chartHeight * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);
      final tp = TextPainter(text: TextSpan(text: '${(100 - i * 25)}', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(padding.left - tp.width - 6, y - tp.height / 2));
    }

    final labels = ['Now', '30d', '60d', '90d'];
    for (int i = 0; i < 4; i++) {
      final x = padding.left + chartWidth * i / 3;
      final tp = TextPainter(text: TextSpan(text: labels[i], style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 20));
    }

    for (int si = 0; si < predictions.length; si++) {
      final p = predictions[si];
      final points = [
        p['current'] as double,
        p['in30'] as double,
        p['in60'] as double,
        p['in90'] as double,
      ];
      paint.color = colors[si % colors.length];

      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final x = padding.left + chartWidth * i / 3;
        final y = padding.top + chartHeight * (1 - points[i] / 100);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      for (int i = 0; i < points.length; i++) {
        final x = padding.left + chartWidth * i / 3;
        final y = padding.top + chartHeight * (1 - points[i] / 100);
        dotPaint.color = colors[si % colors.length];
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = const Color(0xFF1E1E1E));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
