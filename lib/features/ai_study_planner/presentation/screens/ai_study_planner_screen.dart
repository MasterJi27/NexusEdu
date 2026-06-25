import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiStudyPlannerScreen extends StatefulWidget {
  const AiStudyPlannerScreen({super.key});

  @override
  State<AiStudyPlannerScreen> createState() => _AiStudyPlannerScreenState();
}

class _AiStudyPlannerScreenState extends State<AiStudyPlannerScreen> {
  DateTime? _examDate;
  final List<Map<String, dynamic>> _subjects = [
    {'name': 'Physics', 'priority': 'High', 'chapters': ['Electrostatics', 'Optics', 'Modern Physics']},
    {'name': 'Chemistry', 'priority': 'Medium', 'chapters': ['Organic', 'Inorganic', 'Physical']},
    {'name': 'Maths', 'priority': 'High', 'chapters': ['Calculus', 'Algebra', 'Coordinate Geometry']},
  ];
  bool _isGenerating = false;
  List<Map<String, dynamic>> _dailyPlan = [];
  List<Map<String, dynamic>> _planHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('study_planner_data') ?? [];
    setState(() {
      _planHistory = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
      if (_planHistory.isNotEmpty) {
        _dailyPlan = List<Map<String, dynamic>>.from(
            _planHistory.first['plan'] ?? []);
      }
    });
  }

  Future<void> _savePlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'study_planner_data',
      _planHistory.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _generatePlan() async {
    if (_examDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an exam date first'),
          backgroundColor: Colors.orangeAccent.withAlpha(200),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final daysLeft = _examDate!.difference(DateTime.now()).inDays;
    final subjectList = _subjects
        .map((s) => "${s['name']} (Priority: ${s['priority']})")
        .join(', ');

    final prompt = "Create a study plan for $daysLeft days until the exam. "
        "Subjects: $subjectList. "
        "Generate a JSON array of daily tasks. Each object must have: "
        "\"time\" (string, e.g. '9:00 AM'), \"subject\" (string), "
        "\"task\" (string), \"duration\" (string, e.g. '45 min'), "
        "\"type\" (string, one of: study/review/practice/break). "
        "Include 6-8 tasks per day. No markdown, no code fences. Raw JSON only.";

    final result = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    try {
      String jsonStr = result.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        jsonStr = lines.join('\n').trim();
      }

      final List<dynamic> parsed = json.decode(jsonStr);
      final plan = parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      setState(() {
        _dailyPlan = plan;
        _isGenerating = false;
      });

      _planHistory.insert(0, {
        'examDate': _examDate!.toIso8601String(),
        'plan': plan,
        'created': DateTime.now().toIso8601String(),
      });
      if (_planHistory.length > 10) _planHistory.removeLast();
      _savePlan();
    } catch (_) {
      setState(() => _isGenerating = false);
    }
  }

  void _toggleTask(int index) {
    setState(() {
      _dailyPlan[index]['completed'] = !(_dailyPlan[index]['completed'] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'AI Study Planner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExamDatePicker(),
            const SizedBox(height: 16),
            _buildSubjectList(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generatePlan,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating ? 'Generating Plan...' : 'Generate Plan',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_dailyPlan.isNotEmpty) ...[
              _buildProgressCard(),
              const SizedBox(height: 16),
              _buildTodayPlanCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamDatePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _examDate ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.deepPurpleAccent,
                  surface: Color(0xFF1E1E1E),
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) setState(() => _examDate = date);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today,
                  color: Colors.deepPurpleAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _examDate != null
                        ? '${_examDate!.day}/${_examDate!.month}/${_examDate!.year}'
                        : 'Tap to select exam date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _examDate != null
                          ? Colors.white
                          : Colors.white.withAlpha(120),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withAlpha(100)),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: -0.06);
  }

  Widget _buildSubjectList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subjects & Priority',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_subjects.length, (i) {
            final subject = _subjects[i];
            final priorityColor = subject['priority'] == 'High'
                ? Colors.redAccent
                : subject['priority'] == 'Medium'
                    ? Colors.orangeAccent
                    : Colors.greenAccent;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (subject['chapters'] as List).join(' • '),
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      subject['priority'],
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildProgressCard() {
    final completed =
        _dailyPlan.where((t) => t['completed'] == true).length;
    final total = _dailyPlan.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withAlpha(30),
            Colors.teal.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$completed/$total tasks',
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withAlpha(15),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            borderRadius: BorderRadius.circular(6),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).round()}% Complete',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildTodayPlanCard() {
    final taskTypeIcons = {
      'study': Icons.menu_book,
      'review': Icons.replay,
      'practice': Icons.quiz,
      'break': Icons.coffee,
    };
    final taskTypeColors = {
      'study': Colors.deepPurpleAccent,
      'review': Colors.tealAccent,
      'practice': Colors.orangeAccent,
      'break': Colors.greenAccent,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_dailyPlan.length, (i) {
            final task = _dailyPlan[i];
            final type = task['type'] ?? 'study';
            final isCompleted = task['completed'] == true;
            final color = taskTypeColors[type] ?? Colors.deepPurpleAccent;
            final icon = taskTypeIcons[type] ?? Icons.circle;

            return GestureDetector(
              onTap: () => _toggleTask(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.tealAccent.withAlpha(15)
                      : Colors.black.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.tealAccent.withAlpha(40)
                        : Colors.white.withAlpha(10),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['time'] ?? '',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            task['task'] ?? '',
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.white.withAlpha(100)
                                  : Colors.white.withAlpha(200),
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            '${task['subject']} • ${task['duration'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          isCompleted ? Colors.tealAccent : Colors.white38,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fade(delay: 300.ms);
  }
}
