import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class ParentReportScreen extends StatefulWidget {
  const ParentReportScreen({super.key});

  @override
  State<ParentReportScreen> createState() => _ParentReportScreenState();
}

class _ParentReportScreenState extends State<ParentReportScreen> {
  bool _isLoading = false;
  String _generatedReport = '';
  Map<String, dynamic> _studentData = {};
  List<Map<String, dynamic>> _pastReports = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final studyLogs = prefs.getStringList('study_logs') ?? [];
    final examPredictions = prefs.getStringList('exam_predictions') ?? [];
    final anxietySessions = prefs.getStringList('anxiety_sessions') ?? [];
    final studyStreak = prefs.getInt('study_streak') ?? 0;

    final recentLogs =
        studyLogs.length > 7 ? studyLogs.sublist(studyLogs.length - 7) : studyLogs;

    double totalHours = 0;
    final subjects = <String, double>{};
    for (final log in recentLogs) {
      try {
        final data = jsonDecode(log) as Map<String, dynamic>;
        final hours = double.tryParse(data['hours']?.toString() ?? '0') ?? 0;
        totalHours += hours;
        final subject = data['subject'] ?? 'Unknown';
        subjects[subject] = (subjects[subject] ?? 0) + hours;
      } catch (_) {}
    }

    _studentData = {
      'studyStreak': studyStreak,
      'totalHoursWeek': totalHours,
      'subjects': subjects,
      'totalTests': examPredictions.length,
      'wellnessSessions': anxietySessions.length,
    };

    final saved = prefs.getStringList('parent_reports');
    if (saved != null) {
      _pastReports =
          saved.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    }

    setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _generatedReport = '';
    });

    final subjectsStr = (_studentData['subjects'] as Map<String, dynamic>?)
            ?.entries
            .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}h')
            .join(', ') ??
        'No data';

    final prompt =
        'Generate a weekly student performance report for parents.\n'
        'Study streak: ${_studentData["studyStreak"]} days\n'
        'Total study hours this week: ${(_studentData["totalHoursWeek"] as double).toStringAsFixed(1)}h\n'
        'Subjects studied: $subjectsStr\n'
        'Wellness sessions: ${_studentData["wellnessSessions"]}\n\n'
        'Create a formal report card with: '
        '1) Subject-wise performance summary (estimate scores based on hours)\n'
        '2) Attendance note (assume 90%+)\n'
        '3) Behavior observation\n'
        '4) Strengths\n'
        '5) Areas for improvement\n'
        '6) Parent suggestions\n'
        'Format it nicely with sections and be encouraging but honest.';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    setState(() {
      _generatedReport = response;
      _isLoading = false;
    });

    _saveReport(response);
  }

  Future<void> _saveReport(String report) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('parent_reports') ?? [];
    history.add(jsonEncode({
      'report': report,
      'data': {
        'studyStreak': _studentData['studyStreak'],
        'totalHoursWeek': _studentData['totalHoursWeek'],
        'totalTests': _studentData['totalTests'],
        'wellnessSessions': _studentData['wellnessSessions'],
      },
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 20) history.removeAt(0);
    await prefs.setStringList('parent_reports', history);
    _loadData();
  }

  void _copyReport() {
    if (_generatedReport.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _generatedReport));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report copied to clipboard'),
        backgroundColor: Colors.deepPurpleAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title:
            const Text('Parent Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_generatedReport.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white70),
              onPressed: _copyReport,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStudentOverview(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _generateReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Report',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          if (_generatedReport.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildReportCard(),
          ],
          if (_pastReports.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildPastReports(),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentOverview() {
    final totalHours = (_studentData['totalHoursWeek'] as double?) ?? 0;
    final streak = _studentData['studyStreak'] ?? 0;
    final subjects = (_studentData['subjects'] as Map<String, dynamic>?) ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Student Weekly Overview',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatChip(Icons.local_fire_department, 'Streak', '$streak days', Colors.orangeAccent),
              const SizedBox(width: 10),
              _buildStatChip(Icons.access_time, 'Hours', '${totalHours.toStringAsFixed(1)}h', Colors.cyanAccent),
              const SizedBox(width: 10),
              _buildStatChip(Icons.psychology, 'Wellness', '${_studentData["wellnessSessions"] ?? 0}', Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 12),
          if (subjects.isNotEmpty) ...[
            const Text('Subject Breakdown', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            ...subjects.entries.map((entry) {
              final pct = totalHours > 0 ? (entry.value / totalHours) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(entry.key, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white.withAlpha(20),
                          valueColor: const AlwaysStoppedAnimation(Colors.deepPurpleAccent),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    ).animate().fade();
  }

  Widget _buildStatChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              const Text('Weekly Report Card',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: _copyReport,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Share', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            _generatedReport,
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, height: 1.6),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildPastReports() {
    final recent = _pastReports.reversed.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Past Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...recent.asMap().entries.map((entry) {
            final i = entry.key;
            final report = entry.value;
            final ts = report['timestamp'] ?? '';
            String dateStr = '';
            try {
              final dt = DateTime.parse(ts);
              dateStr = '${dt.day}/${dt.month}/${dt.year}';
            } catch (_) {
              dateStr = ts;
            }
            return GestureDetector(
              onTap: () {
                setState(() {
                  _generatedReport = report['report'] ?? '';
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Colors.deepPurpleAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Report ${recent.length - i}',
                              style: TextStyle(color: Colors.white.withAlpha(200), fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(dateStr, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white.withAlpha(80)),
                  ],
                ),
              ),
            ).animate().fade(delay: Duration(milliseconds: i * 80));
          }),
        ],
      ),
    );
  }
}
