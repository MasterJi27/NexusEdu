import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OptimalStudyTimeScreen extends StatefulWidget {
  const OptimalStudyTimeScreen({super.key});

  @override
  State<OptimalStudyTimeScreen> createState() => _OptimalStudyTimeScreenState();
}

class _OptimalStudyTimeScreenState extends State<OptimalStudyTimeScreen> {
  bool _isLoading = false;
  bool _hasResult = false;

  String _selectedSubject = 'Maths';
  int _selectedHour = 9;
  double _performance = 70;
  List<Map<String, dynamic>> _logs = [];
  Map<String, List<double>> _heatmap = {};
  List<String> _recommendations = [];

  final _subjects = ['Maths', 'Physics', 'Chemistry', 'Biology', 'English', 'History'];
  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('study_time_logs') ?? [];
    setState(() {
      _logs = saved.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
    _buildHeatmap();
  }

  void _buildHeatmap() {
    _heatmap = {};
    for (final log in _logs) {
      final hour = log['hour'] as int? ?? 12;
      final day = log['day'] as String? ?? 'Mon';
      final perf = (log['performance'] as num?)?.toDouble() ?? 50;
      final key = '${day}_$hour';
      _heatmap[key] = [...(_heatmap[key] ?? []), perf];
    }
  }

  Future<void> _addSession() async {
    final log = {
      'subject': _selectedSubject,
      'hour': _selectedHour,
      'day': _days[Random().nextInt(7)],
      'performance': _performance,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _logs.insert(0, log);
    if (_logs.length > 200) _logs.removeLast();
    _buildHeatmap();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'study_time_logs',
      _logs.map((e) => json.encode(e)).toList(),
    );
    setState(() {});
  }

  Future<void> _analyze() async {
    setState(() => _isLoading = true);

    final hourPerformance = <int, List<double>>{};
    for (final log in _logs) {
      final hour = log['hour'] as int? ?? 12;
      final perf = (log['performance'] as num?)?.toDouble() ?? 50;
      hourPerformance[hour] = [...(hourPerformance[hour] ?? []), perf];
    }

    final bestHours = <String, int>{};
    for (final subject in _subjects) {
      final subjectLogs = _logs.where((l) => l['subject'] == subject).toList();
      if (subjectLogs.isNotEmpty) {
        final best = subjectLogs
            .fold<MapEntry<int, double>?>(
              null,
              (prev, l) {
                final h = l['hour'] as int;
                final p = (l['performance'] as num?)?.toDouble() ?? 0;
                return prev == null || p > prev.value ? MapEntry(h, p) : prev;
              },
            );
        if (best != null) {
          final hourLabel = best.key < 12 ? '${best.key} AM' : best.key == 12 ? '12 PM' : '${best.key - 12} PM';
          bestHours[subject] = best.key;
          _recommendations.add('Study $subject at $hourLabel for peak performance');
        }
      }
    }

    if (_recommendations.isEmpty) {
      _recommendations = [
        'Log study sessions to get personalized time recommendations',
        'Morning (8-11 AM) is typically best for analytical subjects',
        'Evening (4-7 PM) works well for creative subjects',
        'Night sessions are good for revision and memorization',
      ];
    }

    try {
      final response = await AiAgentService.callAgent('custom', {
        'prompt': 'Analyze optimal study times:\n'
            'Logs: ${_logs.length} sessions\n'
            'Best hours per subject: $bestHours\n'
            'Provide 3 study time recommendations.',
      });
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length >= 3) {
        _recommendations = lines.map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()).toList();
      }
    } catch (_) {}

    setState(() {
      _isLoading = false;
      _hasResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Optimal Study Time AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionLogger(),
            const SizedBox(height: 16),
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
                    : const Icon(Icons.access_time),
                label: Text(_isLoading ? 'Analyzing...' : 'Analyze Best Hours', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildHeatmapGrid(),
              const SizedBox(height: 20),
              _buildRecommendations(),
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
                child: DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    filled: true,
                    fillColor: Colors.black.withAlpha(30),
                  ),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedHour,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Hour',
                    labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
                    filled: true,
                    fillColor: Colors.black.withAlpha(30),
                  ),
                  items: List.generate(16, (i) => i + 6).map((h) {
                    final label = h < 12 ? '$h AM' : h == 12 ? '12 PM' : '${h - 12} PM';
                    return DropdownMenuItem(value: h, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedHour = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Performance: ${_performance.toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
          Slider(
            value: _performance,
            min: 0,
            max: 100,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: Colors.white.withAlpha(20),
            onChanged: (v) => setState(() => _performance = v),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addSession,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.deepPurpleAccent.withAlpha(100)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, color: Colors.deepPurpleAccent, size: 18),
              label: const Text('Add Session', style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildHeatmapGrid() {
    final hours = List.generate(16, (i) => i + 6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Productivity Heatmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${_logs.length} sessions logged', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: CustomPaint(
              size: const Size(double.infinity, 300),
              painter: _HeatmapPainter(
                heatmap: _heatmap,
                days: _days,
                hours: hours,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.greenAccent, 'High'),
              const SizedBox(width: 16),
              _buildLegend(Colors.amberAccent, 'Medium'),
              const SizedBox(width: 16),
              _buildLegend(Colors.redAccent, 'Low'),
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

  Widget _buildRecommendations() {
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
          const Text('AI Recommendations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.deepPurpleAccent.withAlpha(200), size: 16),
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

class _HeatmapPainter extends CustomPainter {
  final Map<String, List<double>> heatmap;
  final List<String> days;
  final List<int> hours;

  _HeatmapPainter({required this.heatmap, required this.days, required this.hours});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.fromLTRB(40, 10, 20, 40);
    final cellWidth = (size.width - padding.left - padding.right) / hours.length;
    final cellHeight = (size.height - padding.top - padding.bottom) / days.length;

    for (int d = 0; d < days.length; d++) {
      final tp = TextPainter(
        text: TextSpan(text: days[d], style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padding.left - tp.width - 6, padding.top + d * cellHeight + cellHeight / 2 - tp.height / 2));
    }

    for (int h = 0; h < hours.length; h++) {
      final hour = hours[h];
      final label = hour < 12 ? '${hour}a' : hour == 12 ? '12p' : '${hour - 12}p';
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padding.left + h * cellWidth + cellWidth / 2 - tp.width / 2, size.height - 30));
    }

    for (int d = 0; d < days.length; d++) {
      for (int h = 0; h < hours.length; h++) {
        final key = '${days[d]}_${hours[h]}';
        final values = heatmap[key];
        final avgPerf = values != null && values.isNotEmpty
            ? values.reduce((a, b) => a + b) / values.length
            : -1.0;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(padding.left + h * cellWidth + 2, padding.top + d * cellHeight + 2, cellWidth - 4, cellHeight - 4),
          const Radius.circular(4),
        );

        Color cellColor;
        if (avgPerf < 0) {
          cellColor = Colors.white.withAlpha(8);
        } else if (avgPerf >= 70) {
          cellColor = Colors.greenAccent.withAlpha((100 + avgPerf).toInt().clamp(100, 255));
        } else if (avgPerf >= 50) {
          cellColor = Colors.amberAccent.withAlpha((80 + avgPerf).toInt().clamp(80, 200));
        } else {
          cellColor = Colors.redAccent.withAlpha((60 + avgPerf).toInt().clamp(60, 180));
        }

        canvas.drawRRect(rect, Paint()..color = cellColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
