import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ComparativeAnalyticsScreen extends StatefulWidget {
  const ComparativeAnalyticsScreen({super.key});

  @override
  State<ComparativeAnalyticsScreen> createState() => _ComparativeAnalyticsScreenState();
}

class _ComparativeAnalyticsScreenState extends State<ComparativeAnalyticsScreen> {
  final Map<String, TextEditingController> _yourScoreControllers = {};
  final Map<String, TextEditingController> _classAvgControllers = {};
  bool _isLoading = false;
  bool _hasResult = false;

  final _subjects = ['Physics', 'Chemistry', 'Maths', 'Biology'];
  Map<String, double> _yourScores = {};
  Map<String, double> _classAvg = {};
  Map<String, double> _differences = {};
  Map<String, String> _rankings = {};
  List<Map<String, dynamic>> _pastData = [];

  @override
  void initState() {
    super.initState();
    for (final s in _subjects) {
      _yourScoreControllers[s] = TextEditingController();
      _classAvgControllers[s] = TextEditingController();
    }
    _loadPastData();
  }

  @override
  void dispose() {
    for (final c in [..._yourScoreControllers.values, ..._classAvgControllers.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPastData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('comparative_data') ?? [];
    setState(() {
      _pastData = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
  }

  Future<void> _analyze() async {
    for (final s in _subjects) {
      final your = double.tryParse(_yourScoreControllers[s]!.text.trim());
      final avg = double.tryParse(_classAvgControllers[s]!.text.trim());
      if (your == null || avg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter valid scores for $s')),
        );
        return;
      }
      _yourScores[s] = your;
      _classAvg[s] = avg;
    }

    setState(() => _isLoading = true);

    _differences = {};
    _rankings = {};
    for (final s in _subjects) {
      final diff = _yourScores[s]! - _classAvg[s]!;
      _differences[s] = diff;

      final percentile = LocalComputation.calculatePercentile(
        _yourScores[s]!,
        _classAvg.values.toList(),
      );

      if (percentile >= 95) {
        _rankings[s] = 'Top 5%';
      } else if (percentile >= 90) {
        _rankings[s] = 'Top 10%';
      } else if (percentile >= 75) {
        _rankings[s] = 'Top 25%';
      } else if (percentile >= 50) {
        _rankings[s] = 'Above Average';
      } else {
        _rankings[s] = 'Below Average';
      }
    }

    try {
      await AiAgentService.callAgent('custom', {
        'prompt': 'Comparative analytics:\n'
            'Your scores: $_yourScores\n'
            'Class averages: $_classAvg\n'
            'Provide subject-wise comparison insights.',
      });
    } catch (_) {}

    final result = {
      'yourScores': _yourScores,
      'classAvg': _classAvg,
      'differences': _differences,
      'rankings': _rankings,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isLoading = false;
      _hasResult = true;
    });

    _pastData.insert(0, result);
    if (_pastData.length > 10) _pastData.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'comparative_data',
      _pastData.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Comparative Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreInputs(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _analyze,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bar_chart),
                label: Text(_isLoading ? 'Analyzing...' : 'Compare', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildBarChart(),
              const SizedBox(height: 20),
              _buildComparisonCards(),
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
          Text('Enter Scores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(150))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Subject', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11))),
              SizedBox(
                width: 80,
                child: Text('You', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11), textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 80,
                child: Text('Class Avg', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11), textAlign: TextAlign.center),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._subjects.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(s, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _yourScoreControllers[s],
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
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _classAvgControllers[s],
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
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildBarChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(
        size: const Size(double.infinity, 220),
        painter: _ComparativeBarPainter(yourScores: _yourScores, classAvg: _classAvg, subjects: _subjects),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildComparisonCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject Comparison', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._subjects.map((s) {
          final diff = _differences[s] ?? 0;
          final isBetter = diff >= 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isBetter ? Colors.greenAccent : Colors.redAccent).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBetter ? Icons.trending_up : Icons.trending_down,
                    color: isBetter ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        isBetter
                            ? 'Your $s is ${diff.toStringAsFixed(0)}% better than average'
                            : 'Your $s is ${diff.abs().toStringAsFixed(0)}% below average',
                        style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: isBetter ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(_rankings[s] ?? '', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    ).animate().fade();
  }
}

class _ComparativeBarPainter extends CustomPainter {
  final Map<String, double> yourScores;
  final Map<String, double> classAvg;
  final List<String> subjects;

  _ComparativeBarPainter({required this.yourScores, required this.classAvg, required this.subjects});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.fromLTRB(50, 20, 20, 40);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    final gridPaint = Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + chartHeight * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${100 - i * 25}', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padding.left - tp.width - 6, y - tp.height / 2));
    }

    final groupWidth = chartWidth / subjects.length;
    final barWidth = groupWidth * 0.3;

    for (int i = 0; i < subjects.length; i++) {
      final groupX = padding.left + i * groupWidth;

      final yourHeight = (yourScores[subjects[i]] ?? 0) / 100 * chartHeight;
      final avgHeight = (classAvg[subjects[i]] ?? 0) / 100 * chartHeight;

      final yourRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(groupX + 4, padding.top + chartHeight - yourHeight, barWidth, yourHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(yourRect, Paint()..color = Colors.deepPurpleAccent);

      final avgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(groupX + barWidth + 8, padding.top + chartHeight - avgHeight, barWidth, avgHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(avgRect, Paint()..color = Colors.white.withAlpha(60));

      final labelTp = TextPainter(
        text: TextSpan(text: subjects[i].substring(0, min(4, subjects[i].length)), style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(canvas, Offset(groupX + groupWidth / 2 - labelTp.width / 2, size.height - 25));
    }

    final legendY = size.height - 10;
    canvas.drawRect(Rect.fromLTWH(padding.left, legendY - 6, 10, 10), Paint()..color = Colors.deepPurpleAccent);
    final youTp = TextPainter(text: TextSpan(text: 'You', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 9)), textDirection: TextDirection.ltr)..layout();
    youTp.paint(canvas, Offset(padding.left + 14, legendY - 5));

    canvas.drawRect(Rect.fromLTWH(padding.left + 50, legendY - 6, 10, 10), Paint()..color = Colors.white.withAlpha(60));
    final avgTp = TextPainter(text: TextSpan(text: 'Class Avg', style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 9)), textDirection: TextDirection.ltr)..layout();
    avgTp.paint(canvas, Offset(padding.left + 64, legendY - 5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
