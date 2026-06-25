import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BurnoutDetectorScreen extends StatefulWidget {
  const BurnoutDetectorScreen({super.key});

  @override
  State<BurnoutDetectorScreen> createState() => _BurnoutDetectorScreenState();
}

class _BurnoutDetectorScreenState extends State<BurnoutDetectorScreen> {
  final List<TextEditingController> _scoreControllers = List.generate(7, (_) => TextEditingController());
  final TextEditingController _hoursController = TextEditingController();
  bool _isLoading = false;
  bool _hasResult = false;

  double _burnoutRisk = 0;
  List<String> _riskFactors = [];
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _pastChecks = [];

  @override
  void initState() {
    super.initState();
    _loadPastChecks();
  }

  @override
  void dispose() {
    for (final c in _scoreControllers) {
      c.dispose();
    }
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadPastChecks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('burnout_checks') ?? [];
    setState(() {
      _pastChecks = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
  }

  Future<void> _checkBurnout() async {
    final scores = <double>[];
    for (final c in _scoreControllers) {
      final val = double.tryParse(c.text.trim());
      if (val == null || val < 0 || val > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid scores (0-100) for all 7 days')),
        );
        return;
      }
      scores.add(val);
    }

    final dailyHours = <double>[];
    for (final _ in _scoreControllers) {
      dailyHours.add(4 + Random().nextDouble() * 4);
    }
    final hoursText = _hoursController.text.trim();
    final avgHours = double.tryParse(hoursText) ?? 6;
    dailyHours.fillRange(0, 7, avgHours);

    setState(() => _isLoading = true);

    final risk = LocalComputation.burnoutRisk(scores, dailyHours);
    final riskPercent = (risk * 100).clamp(0, 100);

    _riskFactors = [];
    final scoreTrend = LocalComputation.trend(scores);
    if (scoreTrend < -0.5) _riskFactors.add('Declining scores over the past week');
    if (scoreTrend < -1.0) _riskFactors.add('Sharp decline in academic performance');
    if (avgHours > 8) _riskFactors.add('Studying more than 8 hours daily');
    if (avgHours > 10) _riskFactors.add('Excessive study hours without adequate rest');
    if (scores.last < 40) _riskFactors.add('Very low recent test scores');
    final minScore = scores.reduce(min);
    if (minScore < 30) _riskFactors.add('Score dropped below 30% at least once');
    if (scoreTrend < -0.3 && avgHours > 6) _riskFactors.add('Increasing effort with decreasing results');

    if (_riskFactors.isEmpty) {
      _riskFactors = ['No significant risk factors detected'];
    }

    _suggestions = [];
    if (riskPercent > 70) {
      _suggestions = [
        'Take a complete break for 1-2 days',
        'Reduce study load by at least 50%',
        'Engage in physical exercise daily',
        'Sleep 8+ hours per night',
        'Talk to a counselor or mentor',
      ];
    } else if (riskPercent > 40) {
      _suggestions = [
        'Take regular 15-minute breaks every hour',
        'Lighten your daily study load',
        'Include 30 minutes of exercise',
        'Maintain a consistent sleep schedule',
      ];
    } else {
      _suggestions = [
        'Keep up the good balance!',
        'Continue regular exercise and sleep',
        'Monitor your scores weekly',
      ];
    }

    try {
      final response = await AiAgentService.callAgent('custom', {
        'prompt': 'Burnout risk assessment:\n'
            'Risk: ${riskPercent.toStringAsFixed(0)}%\n'
            'Recent scores: $scores\n'
            'Average hours: $avgHours\n'
            'Provide burnout prevention advice.',
      });
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length >= 3) {
        _suggestions = lines.map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()).toList();
      }
    } catch (_) {}

    final result = {
      'risk': riskPercent,
      'scores': scores,
      'hours': avgHours,
      'riskFactors': _riskFactors,
      'suggestions': _suggestions,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _burnoutRisk = riskPercent.toDouble();
      _isLoading = false;
      _hasResult = true;
    });

    _pastChecks.insert(0, result);
    if (_pastChecks.length > 20) _pastChecks.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'burnout_checks',
      _pastChecks.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Burnout Detector', style: TextStyle(fontWeight: FontWeight.bold)),
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
                onPressed: _isLoading ? null : _checkBurnout,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.warning_amber),
                label: Text(_isLoading ? 'Checking...' : 'Check Burnout Risk', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildBurnoutGauge(),
              const SizedBox(height: 20),
              _buildRiskFactors(),
              const SizedBox(height: 16),
              _buildSuggestions(),
            ],
            if (_pastChecks.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Past Checks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ..._pastChecks.take(5).map((c) => _buildPastCheckCard(c)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreInputs() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Scores (Last 7 Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(days[i], style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 10)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _scoreControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                          filled: true,
                          fillColor: Colors.black.withAlpha(30),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
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
          Text('Average Daily Study Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 8),
          TextField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'e.g. 6',
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

  Widget _buildBurnoutGauge() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('Burnout Risk Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: 260,
            child: CustomPaint(
              painter: _BurnoutGaugePainter(_burnoutRisk),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_burnoutRisk.toStringAsFixed(0)}%',
            style: TextStyle(
              color: _burnoutRisk > 70 ? Colors.redAccent : _burnoutRisk > 40 ? Colors.amberAccent : Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          Text(
            _burnoutRisk > 70 ? 'High Risk' : _burnoutRisk > 40 ? 'Moderate Risk' : 'Low Risk',
            style: TextStyle(
              color: _burnoutRisk > 70 ? Colors.redAccent : _burnoutRisk > 40 ? Colors.amberAccent : Colors.greenAccent,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildRiskFactors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk Factors', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._riskFactors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amberAccent.withAlpha(200), size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13))),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildSuggestions() {
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
          const Text('Suggestions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent.withAlpha(200), size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13))),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildPastCheckCard(Map<String, dynamic> c) {
    final risk = c['risk'] as double;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (risk > 70 ? Colors.redAccent : risk > 40 ? Colors.amberAccent : Colors.greenAccent).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              risk > 70 ? Icons.warning : Icons.check_circle,
              color: risk > 70 ? Colors.redAccent : risk > 40 ? Colors.amberAccent : Colors.greenAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${risk.toStringAsFixed(0)}% risk', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${c['timestamp']?.toString().substring(0, 10) ?? ''}',
                    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BurnoutGaugePainter extends CustomPainter {
  final double risk;

  _BurnoutGaugePainter(this.risk);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width / 2 - 10;
    const startAngle = pi;
    const sweepAngle = pi;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false, bgPaint,
    );

    final valPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final ratio = (risk / 100).clamp(0.0, 1.0);
    valPaint.shader = LinearGradient(
      colors: const [Colors.greenAccent, Colors.amberAccent, Colors.redAccent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * ratio, false, valPaint,
    );

    final angle = startAngle + sweepAngle * ratio;
    final needleEnd = Offset(
      center.dx + (radius - 25) * cos(angle),
      center.dy + (radius - 25) * sin(angle),
    );

    canvas.drawLine(
      center, needleEnd,
      Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
