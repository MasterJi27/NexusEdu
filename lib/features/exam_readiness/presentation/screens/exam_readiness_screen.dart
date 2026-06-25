import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExamReadinessScreen extends StatefulWidget {
  const ExamReadinessScreen({super.key});

  @override
  State<ExamReadinessScreen> createState() => _ExamReadinessScreenState();
}

class _ExamReadinessScreenState extends State<ExamReadinessScreen> {
  String _selectedExam = 'JEE';
  bool _isLoading = false;
  bool _hasResult = false;

  final Map<String, TextEditingController> _scoreControllers = {};
  double _overallReadiness = 0;
  Map<String, double> _subjectReadiness = {};
  String _focusArea = '';
  List<Map<String, dynamic>> _pastReadiness = [];

  final _examSubjects = {
    'JEE': ['Physics', 'Chemistry', 'Maths'],
    'NEET': ['Physics', 'Chemistry', 'Biology'],
    'CBSE Board': ['Physics', 'Chemistry', 'Maths', 'Biology', 'English'],
  };

  List<String> get _currentSubjects => _examSubjects[_selectedExam] ?? [];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPastReadiness();
  }

  void _initControllers() {
    for (final s in _currentSubjects) {
      _scoreControllers[s] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPastReadiness() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('exam_readiness') ?? [];
    setState(() {
      _pastReadiness = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
  }

  void _onExamChanged(String? exam) {
    if (exam == null || exam == _selectedExam) return;
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    _scoreControllers.clear();
    setState(() {
      _selectedExam = exam;
      _hasResult = false;
    });
    _initControllers();
  }

  Future<void> _calculate() async {
    final scores = <String, double>{};
    for (final s in _currentSubjects) {
      final val = double.tryParse(_scoreControllers[s]!.text.trim());
      if (val == null || val < 0 || val > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter valid score for $s (0-100)')),
        );
        return;
      }
      scores[s] = val;
    }

    setState(() => _isLoading = true);

    final weights = {
      'JEE': {'Physics': 0.33, 'Chemistry': 0.33, 'Maths': 0.34},
      'NEET': {'Physics': 0.25, 'Chemistry': 0.25, 'Biology': 0.50},
      'CBSE Board': {'Physics': 0.2, 'Chemistry': 0.2, 'Maths': 0.2, 'Biology': 0.2, 'English': 0.2},
    };

    final examWeights = weights[_selectedExam] ?? {};
    double weightedSum = 0;
    double totalWeight = 0;

    _subjectReadiness = {};
    for (final entry in scores.entries) {
      final weight = examWeights[entry.key] ?? 1.0 / _currentSubjects.length;
      final readiness = entry.value * 0.9 + Random().nextDouble() * 10;
      _subjectReadiness[entry.key] = readiness.clamp(0, 100);
      weightedSum += readiness * weight;
      totalWeight += weight;
    }

    _overallReadiness = totalWeight > 0 ? (weightedSum / totalWeight).clamp(0, 100) : 0;

    final weakest = _subjectReadiness.entries.reduce(
      (a, b) => a.value < b.value ? a : b,
    );
    _focusArea = weakest.key;

    try {
      await AiAgentService.callAgent('prediction', {
        'scores': scores.values.toList(),
        'hours': 6,
        'days_left': 90,
      });
    } catch (_) {}

    final result = {
      'exam': _selectedExam,
      'scores': scores,
      'overallReadiness': _overallReadiness,
      'subjectReadiness': _subjectReadiness,
      'focusArea': _focusArea,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isLoading = false;
      _hasResult = true;
    });

    _pastReadiness.insert(0, result);
    if (_pastReadiness.length > 10) _pastReadiness.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'exam_readiness',
      _pastReadiness.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Exam Readiness Score', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExamSelector(),
            const SizedBox(height: 16),
            _buildScoreInputs(),
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
                    : const Icon(Icons.school),
                label: Text(_isLoading ? 'Calculating...' : 'Calculate Readiness', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildReadinessGauge(),
              const SizedBox(height: 20),
              _buildSubjectBars(),
              const SizedBox(height: 20),
              _buildFocusRecommendation(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Target Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examSubjects.keys.map((exam) {
              final isSelected = exam == _selectedExam;
              return GestureDetector(
                onTap: () => _onExamChanged(exam),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurpleAccent.withAlpha(40) : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(15)),
                  ),
                  child: Text(exam, style: TextStyle(
                    color: isSelected ? Colors.deepPurpleAccent : Colors.white.withAlpha(150),
                    fontWeight: FontWeight.bold, fontSize: 13,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildScoreInputs() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Scores (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 12),
          ..._currentSubjects.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _scoreControllers[s],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '0-100',
                          hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                          filled: true,
                          fillColor: Colors.black.withAlpha(30),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ..._currentSubjects.map((s) {
            if (_scoreControllers[s] == null) {
              _scoreControllers[s] = TextEditingController();
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildReadinessGauge() {
    final color = _overallReadiness >= 70
        ? Colors.greenAccent
        : _overallReadiness >= 50
            ? Colors.amberAccent
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('$_selectedExam Readiness', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: 260,
            child: CustomPaint(
              painter: _ReadinessGaugePainter(_overallReadiness),
            ),
          ),
          const SizedBox(height: 8),
          Text('${_overallReadiness.toStringAsFixed(0)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 36)),
          Text(
            _overallReadiness >= 70 ? 'You\'re on track!' : _overallReadiness >= 50 ? 'Good progress, keep going' : 'Needs improvement',
            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildSubjectBars() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subject Readiness', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ..._subjectReadiness.entries.map((entry) {
            final color = entry.value >= 70
                ? Colors.greenAccent
                : entry.value >= 50
                    ? Colors.amberAccent
                    : Colors.redAccent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${entry.value.toStringAsFixed(0)}%',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / 100,
                      minHeight: 10,
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

  Widget _buildFocusRecommendation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Focus Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'You\'re ${_overallReadiness.toStringAsFixed(0)}% ready — focus on $_focusArea',
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amberAccent.withAlpha(200), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dedicate ${_subjectReadiness[_focusArea] != null && _subjectReadiness[_focusArea]! < 50 ? 'extra' : 'more'} time to $_focusArea to boost your overall readiness.',
                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade();
  }
}

class _ReadinessGaugePainter extends CustomPainter {
  final double readiness;

  _ReadinessGaugePainter(this.readiness);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final ratio = (readiness / 100).clamp(0.0, 1.0);
    final valPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    valPaint.shader = SweepGradient(
      startAngle: -pi / 2,
      colors: const [Colors.redAccent, Colors.amberAccent, Colors.greenAccent],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * ratio,
      false,
      valPaint,
    );

    final iconPaint = Paint()..color = Colors.white;
    final iconSize = radius * 0.35;
    final iconCenter = Offset(center.dx, center.dy - iconSize * 0.1);

    final path = Path();
    path.moveTo(iconCenter.dx, iconCenter.dy - iconSize * 0.5);
    path.lineTo(iconCenter.dx + iconSize * 0.4, iconCenter.dy + iconSize * 0.1);
    path.lineTo(iconCenter.dx + iconSize * 0.15, iconCenter.dy + iconSize * 0.1);
    path.lineTo(iconCenter.dx + iconSize * 0.15, iconCenter.dy + iconSize * 0.5);
    path.lineTo(iconCenter.dx - iconSize * 0.15, iconCenter.dy + iconSize * 0.5);
    path.lineTo(iconCenter.dx - iconSize * 0.15, iconCenter.dy + iconSize * 0.1);
    path.lineTo(iconCenter.dx - iconSize * 0.4, iconCenter.dy + iconSize * 0.1);
    path.close();

    canvas.drawPath(path, iconPaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
