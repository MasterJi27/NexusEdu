import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyEfficiencyScreen extends StatefulWidget {
  const StudyEfficiencyScreen({super.key});

  @override
  State<StudyEfficiencyScreen> createState() => _StudyEfficiencyScreenState();
}

class _StudyEfficiencyScreenState extends State<StudyEfficiencyScreen> {
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _topicsController = TextEditingController();
  double _retentionRating = 5;
  bool _isLoading = false;
  bool _hasResult = false;

  double _efficiencyScore = 0;
  double _effectiveMinutes = 0;
  double _totalMinutes = 0;
  List<double> _weeklyTrend = [];
  List<Map<String, dynamic>> _pastLogs = [];

  @override
  void initState() {
    super.initState();
    _loadPastLogs();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  Future<void> _loadPastLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('efficiency_logs') ?? [];
    setState(() {
      _pastLogs = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
    _buildWeeklyTrend();
  }

  void _buildWeeklyTrend() {
    final now = DateTime.now();
    _weeklyTrend = List.generate(7, (i) {
      final dayLogs = _pastLogs.where((l) {
        final ts = DateTime.tryParse(l['timestamp'] ?? '');
        return ts != null && ts.isAfter(now.subtract(Duration(days: i + 1))) && ts.isBefore(now.subtract(Duration(days: i)));
      }).toList();
      if (dayLogs.isEmpty) return 0.0;
      return dayLogs.map((l) => (l['efficiency'] as num?)?.toDouble() ?? 0).reduce((a, b) => a + b) / dayLogs.length;
    }).reversed.toList();
  }

  Future<void> _calculate() async {
    final hours = double.tryParse(_hoursController.text.trim());
    final topics = int.tryParse(_topicsController.text.trim());
    if (hours == null || hours <= 0 || topics == null || topics <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid hours and topics covered')),
      );
      return;
    }

    setState(() => _isLoading = true);

    _totalMinutes = hours * 60;
    final efficiency = LocalComputation.studyEfficiency(hours, topics, _retentionRating / 10);
    _efficiencyScore = (efficiency * 10).clamp(0, 100);
    _effectiveMinutes = _totalMinutes * (_efficiencyScore / 100);

    try {
      final response = await AiAgentService.callAgent('custom', {
        'prompt': 'Study efficiency analysis:\n'
            'Hours studied: $hours\n'
            'Topics covered: $topics\n'
            'Self-rated retention: $_retentionRating/10\n'
            'Efficiency score: ${_efficiencyScore.toStringAsFixed(0)}/100\n'
            'Provide 3 tips to improve study efficiency.',
      });
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length >= 3) {
        _pastLogs.last['tips'] = lines.map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()).toList();
      }
    } catch (_) {}

    final result = {
      'hours': hours,
      'topics': topics,
      'retention': _retentionRating,
      'efficiency': _efficiencyScore,
      'effectiveMinutes': _effectiveMinutes,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isLoading = false;
      _hasResult = true;
    });

    _pastLogs.insert(0, result);
    if (_pastLogs.length > 50) _pastLogs.removeLast();
    _buildWeeklyTrend();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'efficiency_logs',
      _pastLogs.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Study Efficiency Score', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionLogger(),
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
                    : const Icon(Icons.speed),
                label: Text(_isLoading ? 'Calculating...' : 'Calculate', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildEfficiencyGauge(),
              const SizedBox(height: 20),
              _buildTimeComparison(),
              const SizedBox(height: 20),
              _buildWeeklyTrendChart(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionLogger() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log Study Session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Hours',
                    labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                    hintText: 'e.g. 2.5',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    filled: true,
                    fillColor: Colors.black.withAlpha(30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _topicsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Topics Covered',
                    labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                    hintText: 'e.g. 5',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    filled: true,
                    fillColor: Colors.black.withAlpha(30),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Self-Rated Retention: ${_retentionRating.toInt()}/10',
              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
          Slider(
            value: _retentionRating,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: Colors.white.withAlpha(20),
            onChanged: (v) => setState(() => _retentionRating = v),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildEfficiencyGauge() {
    final color = _efficiencyScore >= 70
        ? Colors.greenAccent
        : _efficiencyScore >= 40
            ? Colors.amberAccent
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('Efficiency Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            width: 200,
            child: CustomPaint(
              painter: _EfficiencyGaugePainter(_efficiencyScore),
            ),
          ),
          const SizedBox(height: 8),
          Text('${_efficiencyScore.toStringAsFixed(0)}/100',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 28)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildTimeComparison() {
    final wastedMinutes = _totalMinutes - _effectiveMinutes;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Time Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTimeBox('Total', '${_totalMinutes.toStringAsFixed(0)} min', Colors.white),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white.withAlpha(80)),
              const SizedBox(width: 8),
              _buildTimeBox('Effective', '${_effectiveMinutes.toStringAsFixed(0)} min', Colors.greenAccent),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white.withAlpha(80)),
              const SizedBox(width: 8),
              _buildTimeBox('Wasted', '${wastedMinutes.toStringAsFixed(0)} min', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You studied ${_totalMinutes.toStringAsFixed(0)} mins but only learned ${_effectiveMinutes.toStringAsFixed(0)} mins worth.',
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildTimeBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(
        size: const Size(double.infinity, 150),
        painter: _WeeklyTrendPainter(trend: _weeklyTrend),
      ),
    ).animate().fadeIn(duration: 800.ms);
  }
}

class _EfficiencyGaugePainter extends CustomPainter {
  final double score;

  _EfficiencyGaugePainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width / 2 - 10;
    const startAngle = pi;
    const sweepAngle = pi;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    final ratio = (score / 100).clamp(0.0, 1.0);
    final valPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    valPaint.shader = LinearGradient(
      colors: const [Colors.redAccent, Colors.amberAccent, Colors.greenAccent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * ratio, false, valPaint);

    final angle = startAngle + sweepAngle * ratio;
    final needleEnd = Offset(center.dx + (radius - 20) * cos(angle), center.dy + (radius - 20) * sin(angle));
    canvas.drawLine(center, needleEnd, Paint()..color = Colors.white..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WeeklyTrendPainter extends CustomPainter {
  final List<double> trend;

  _WeeklyTrendPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;

    final padding = const EdgeInsets.fromLTRB(40, 10, 20, 30);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    final gridPaint = Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + chartHeight * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);
    }

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 0; i < days.length; i++) {
      final x = padding.left + chartWidth * i / (days.length - 1);
      final tp = TextPainter(
        text: TextSpan(text: days[i], style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 20));
    }

    final linePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < trend.length; i++) {
      final x = padding.left + chartWidth * i / (trend.length - 1);
      final y = padding.top + chartHeight * (1 - trend[i] / 100);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = Colors.deepPurpleAccent;
    for (int i = 0; i < trend.length; i++) {
      final x = padding.left + chartWidth * i / (trend.length - 1);
      final y = padding.top + chartHeight * (1 - trend[i] / 100);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = const Color(0xFF1E1E1E));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
