import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgettingCurveAgentScreen extends StatefulWidget {
  const ForgettingCurveAgentScreen({super.key});

  @override
  State<ForgettingCurveAgentScreen> createState() => _ForgettingCurveAgentScreenState();
}

class _ForgettingCurveAgentScreenState extends State<ForgettingCurveAgentScreen> {
  final TextEditingController _topicController = TextEditingController();
  DateTime _lastStudied = DateTime.now().subtract(const Duration(days: 3));
  int _difficulty = 3;
  bool _isLoading = false;
  bool _hasResult = false;

  double _retention = 0;
  List<Map<String, dynamic>> _reviewSchedule = [];
  List<Map<String, dynamic>> _pastCurves = [];

  @override
  void initState() {
    super.initState();
    _loadPastCurves();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadPastCurves() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('forgetting_curves') ?? [];
    setState(() {
      _pastCurves = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
  }

  Future<void> _calculate() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a topic name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final daysSince = DateTime.now().difference(_lastStudied).inDays.toDouble();
    final memoryStrength = 3.0 + _difficulty * 1.5;
    _retention = LocalComputation.forgettingCurve(memoryStrength, daysSince) * 100;

    _reviewSchedule = [];
    for (int day = 1; day <= 30; day++) {
      final reviewRetention = LocalComputation.forgettingCurve(memoryStrength, day.toDouble()) * 100;
      if (reviewRetention < 70 && reviewRetention > 10) {
        _reviewSchedule.add({
          'day': day,
          'date': DateTime.now().add(Duration(days: day)),
          'retention': reviewRetention,
          'urgency': reviewRetention < 40 ? 'high' : 'medium',
        });
      }
    }

    try {
      final response = await AiAgentService.callAgent('custom', {
        'prompt': 'Forgetting curve analysis for topic: $topic\n'
            'Days since last study: ${daysSince.toStringAsFixed(0)}\n'
            'Current retention: ${_retention.toStringAsFixed(1)}%\n'
            'Difficulty: $_difficulty/5\n'
            'Provide 3 specific review tips for this topic.',
      });
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length >= 3) {
        _reviewSchedule.addAll(lines.take(3).map((l) => {
              'tip': l.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim(),
              'day': 0,
            }));
      }
    } catch (_) {}

    final result = {
      'topic': topic,
      'lastStudied': _lastStudied.toIso8601String(),
      'difficulty': _difficulty,
      'retention': _retention,
      'schedule': _reviewSchedule,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isLoading = false;
      _hasResult = true;
    });

    _pastCurves.insert(0, result);
    if (_pastCurves.length > 20) _pastCurves.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'forgetting_curves',
      _pastCurves.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Forgetting Curve Agent', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputSection(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _calculate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.psychology),
                label: Text(_isLoading ? 'Calculating...' : 'Calculate Retention', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildRetentionGauge(),
              const SizedBox(height: 20),
              _buildForgettingCurveGraph(),
              const SizedBox(height: 20),
              _buildReviewSchedule(),
              const SizedBox(height: 16),
              _buildReviewButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Topic Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Topic Name',
              labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
              hintText: 'e.g. Thermodynamics Laws',
              hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
              filled: true,
              fillColor: Colors.black.withAlpha(30),
            ),
          ),
          const SizedBox(height: 12),
          Text('Last Studied', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _lastStudied,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark()),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _lastStudied = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.deepPurpleAccent.withAlpha(200), size: 18),
                  const SizedBox(width: 10),
                  Text(_lastStudied.toString().substring(0, 10),
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Difficulty Level: $_difficulty/5', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150))),
          Slider(
            value: _difficulty.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: Colors.white.withAlpha(20),
            onChanged: (v) => setState(() => _difficulty = v.toInt()),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildRetentionGauge() {
    final color = _retention >= 70
        ? Colors.greenAccent
        : _retention >= 40
            ? Colors.amberAccent
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('Current Retention', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            width: 200,
            child: CustomPaint(
              painter: _RetentionGaugePainter(_retention),
            ),
          ),
          const SizedBox(height: 8),
          Text('${_retention.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 32)),
          Text(
            _retention >= 70 ? 'Good retention — review soon' : _retention >= 40 ? 'Decaying — review recommended' : 'Critical — review now!',
            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildForgettingCurveGraph() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(
        size: const Size(double.infinity, 170),
        painter: _ForgettingCurvePainter(
          memoryStrength: 3.0 + _difficulty * 1.5,
          daysSince: DateTime.now().difference(_lastStudied).inDays.toDouble(),
        ),
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _buildReviewSchedule() {
    final scheduleItems = _reviewSchedule.where((s) => s.containsKey('day') && (s['day'] as int) > 0).take(5).toList();
    final tips = _reviewSchedule.where((s) => s.containsKey('tip')).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Optimal Review Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (scheduleItems.isNotEmpty)
            ...scheduleItems.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (s['urgency'] == 'high' ? Colors.redAccent : Colors.amberAccent).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.event, color: s['urgency'] == 'high' ? Colors.redAccent : Colors.amberAccent, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Day ${s['day']} — ${(s['retention'] as double).toStringAsFixed(0)}% retention',
                          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('AI Tips', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amberAccent.withAlpha(200), size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t['tip'] as String, style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    ).animate().fade();
  }

  Widget _buildReviewButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Starting review session...'), backgroundColor: Colors.deepPurpleAccent),
          );
        },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Review Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ).animate().fade();
  }
}

class _RetentionGaugePainter extends CustomPainter {
  final double retention;

  _RetentionGaugePainter(this.retention);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width / 2 - 10;
    const startAngle = pi;
    const sweepAngle = pi;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    final ratio = (retention / 100).clamp(0.0, 1.0);
    final valPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    valPaint.shader = LinearGradient(
      colors: const [Colors.redAccent, Colors.amberAccent, Colors.greenAccent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * ratio, false, valPaint);

    final angle = startAngle + sweepAngle * ratio;
    final needleEnd = Offset(center.dx + (radius - 18) * cos(angle), center.dy + (radius - 18) * sin(angle));
    canvas.drawLine(center, needleEnd, Paint()..color = Colors.white..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ForgettingCurvePainter extends CustomPainter {
  final double memoryStrength;
  final double daysSince;

  _ForgettingCurvePainter({required this.memoryStrength, required this.daysSince});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.fromLTRB(40, 10, 20, 30);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    final gridPaint = Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + chartHeight * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${100 - i * 25}%', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padding.left - tp.width - 6, y - tp.height / 2));
    }

    for (int i = 0; i <= 7; i++) {
      final x = padding.left + chartWidth * i / 7;
      final tp = TextPainter(
        text: TextSpan(text: 'D$i', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 20));
    }

    final curvePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double d = 0; d <= 7; d += 0.1) {
      final retention = LocalComputation.forgettingCurve(memoryStrength, d) * 100;
      final x = padding.left + chartWidth * d / 7;
      final y = padding.top + chartHeight * (1 - retention / 100);
      if (d == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, curvePaint);

    if (daysSince <= 7) {
      final currentX = padding.left + chartWidth * daysSince / 7;
      final currentRetention = LocalComputation.forgettingCurve(memoryStrength, daysSince) * 100;
      final currentY = padding.top + chartHeight * (1 - currentRetention / 100);

      final dotPaint = Paint()..color = Colors.deepPurpleAccent;
      canvas.drawCircle(Offset(currentX, currentY), 6, dotPaint);
      canvas.drawCircle(Offset(currentX, currentY), 3, Paint()..color = const Color(0xFF1E1E1E));

      final labelTp = TextPainter(
        text: TextSpan(
          text: '${currentRetention.toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(canvas, Offset(currentX - labelTp.width / 2, currentY - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
