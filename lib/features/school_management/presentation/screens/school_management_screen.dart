import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  Map<String, dynamic> _schoolData = {};
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('school_management');
    if (raw != null) {
      _schoolData = Map<String, dynamic>.from(json.decode(raw));
    } else {
      _schoolData = _generateSampleData();
      await _saveData();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('school_management', json.encode(_schoolData));
  }

  Map<String, dynamic> _generateSampleData() {
    return {
      'stats': {
        'studentCount': 342,
        'attendancePercent': 91,
        'averageMarks': 78,
        'activeClasses': 12,
      },
      'students': [
        {
          'name': 'Aarav Mehta',
          'class': '10-A',
          'marks': 85,
          'attendance': 95,
          'behavior': 'excellent',
          'rollNo': '1001',
        },
        {
          'name': 'Saanvi Sharma',
          'class': '10-A',
          'marks': 92,
          'attendance': 98,
          'behavior': 'excellent',
          'rollNo': '1002',
        },
        {
          'name': 'Aditya Verma',
          'class': '10-B',
          'marks': 68,
          'attendance': 82,
          'behavior': 'needs_attention',
          'rollNo': '1003',
        },
        {
          'name': 'Diya Nair',
          'class': '10-A',
          'marks': 78,
          'attendance': 88,
          'behavior': 'good',
          'rollNo': '1004',
        },
        {
          'name': 'Vivaan Gupta',
          'class': '10-B',
          'marks': 55,
          'attendance': 75,
          'behavior': 'needs_attention',
          'rollNo': '1005',
        },
        {
          'name': 'Ananya Singh',
          'class': '10-A',
          'marks': 90,
          'attendance': 97,
          'behavior': 'excellent',
          'rollNo': '1006',
        },
      ],
      'assignments': [
        {
          'title': 'Quadratic Equations Worksheet',
          'subject': 'Mathematics',
          'dueDate': '2026-07-01',
          'description': 'Solve problems 1-20 from Chapter 4',
          'submissions': 28,
          'total': 35,
        },
        {
          'title': 'Newton\'s Laws Lab Report',
          'subject': 'Physics',
          'dueDate': '2026-07-03',
          'description': 'Write lab report on friction experiment',
          'submissions': 22,
          'total': 35,
        },
      ],
      'attendanceLog': {
        '2026-06-25': {
          'present': 310,
          'absent': 20,
          'late': 12,
        },
      },
      'classes': ['10-A', '10-B', '10-C', '9-A', '9-B', '9-C'],
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
        title: const Text('School Management',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
            onPressed: _generateReportCard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent))
          : Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildDashboardTab(),
                      _buildStudentsTab(),
                      _buildAssignmentsTab(),
                      _buildAttendanceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Dashboard', 'Students', 'Assignments', 'Attendance'];
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurpleAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final stats = Map<String, dynamic>.from(_schoolData['stats'] ?? {});
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _dashCard('Students', '${stats['studentCount'] ?? 0}',
                Icons.people, Colors.blue),
            const SizedBox(width: 12),
            _dashCard('Attendance', '${stats['attendancePercent'] ?? 0}%',
                Icons.check_circle, Colors.green),
          ],
        ).animate().fade().slideY(begin: -0.1),
        const SizedBox(height: 12),
        Row(
          children: [
            _dashCard('Avg Marks', '${stats['averageMarks'] ?? 0}%',
                Icons.analytics, Colors.amber),
            const SizedBox(width: 12),
            _dashCard('Classes', '${stats['activeClasses'] ?? 0}',
                Icons.class_, Colors.deepPurpleAccent),
          ],
        ).animate().fade(delay: 100.ms).slideY(begin: -0.1),
        const SizedBox(height: 24),
        const Text('Quick Actions',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _quickAction('Create Assignment', Icons.add_task, () {
          _showCreateAssignmentDialog();
        }),
        _quickAction('Mark Attendance', Icons.how_to_reg, () {
          setState(() => _selectedTab = 3);
        }),
        _quickAction('Generate Report', Icons.description, _generateReportCard),
      ],
    );
  }

  Widget _dashCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 24)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(color: Colors.white.withAlpha(100), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.deepPurpleAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withAlpha(60)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    final students =
        List<Map<String, dynamic>>.from(_schoolData['students'] ?? []);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (ctx, i) => _buildStudentCard(students[i], i),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final behavior = student['behavior'] ?? 'good';
    Color behaviorColor;
    IconData behaviorIcon;
    switch (behavior) {
      case 'excellent':
        behaviorColor = Colors.green;
        behaviorIcon = Icons.star;
        break;
      case 'needs_attention':
        behaviorColor = Colors.redAccent;
        behaviorIcon = Icons.warning;
        break;
      default:
        behaviorColor = Colors.blue;
        behaviorIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: behaviorColor.withAlpha(30),
            child: Text(
              (student['name'] ?? '?')[0],
              style: TextStyle(
                  color: behaviorColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('${student['class']} · Roll ${student['rollNo'] ?? ''}',
                    style: TextStyle(
                        color: Colors.white.withAlpha(100), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniStat(
                      '${student['marks'] ?? 0}%', Colors.blue),
                  const SizedBox(width: 6),
                  _miniStat(
                      '${student['attendance'] ?? 0}%', Colors.green),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(behaviorIcon, color: behaviorColor, size: 14),
                  const SizedBox(width: 2),
                  Text(behavior.toString().replaceAll('_', ' '),
                      style: TextStyle(
                          color: behaviorColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: (50 * index).ms);
  }

  Widget _miniStat(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAssignmentsTab() {
    final assignments =
        List<Map<String, dynamic>>.from(_schoolData['assignments'] ?? []);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: _showCreateAssignmentDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create Assignment'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),
        ...assignments.asMap().entries.map((entry) {
          return _buildAssignmentCard(entry.value, entry.key);
        }),
      ],
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment, int index) {
    final submissions = assignment['submissions'] ?? 0;
    final total = assignment['total'] ?? 1;
    final progress = submissions / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(assignment['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(assignment['subject'] ?? '',
                    style: const TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(assignment['description'] ?? '',
              style:
                  TextStyle(color: Colors.white.withAlpha(120), fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today,
                  color: Colors.white.withAlpha(80), size: 14),
              const SizedBox(width: 4),
              Text('Due: ${assignment['dueDate'] ?? ''}',
                  style: TextStyle(
                      color: Colors.white.withAlpha(100), fontSize: 12)),
              const Spacer(),
              Text('$submissions/$total submitted',
                  style: TextStyle(
                      color: Colors.white.withAlpha(100), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withAlpha(15),
              valueColor: AlwaysStoppedAnimation(
                progress >= 0.8 ? Colors.green : Colors.deepPurpleAccent,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    ).animate().fade(delay: (80 * index).ms);
  }

  Widget _buildAttendanceTab() {
    final log = Map<String, dynamic>.from(
        _schoolData['attendanceLog']?['2026-06-25'] ?? {});
    final present = log['present'] ?? 0;
    final absent = log['absent'] ?? 0;
    final late = log['late'] ?? 0;
    final total = present + absent + late;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('Today\'s Attendance',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attStat('Present', present, Colors.green),
                  _attStat('Absent', absent, Colors.redAccent),
                  _attStat('Late', late, Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                  '${total > 0 ? ((present / total) * 100).toStringAsFixed(0) : 0}% Present',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Class-wise Breakdown',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...(_schoolData['classes'] as List? ?? []).map((cls) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(cls,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 4),
                Text('${85 + (cls.hashCode % 15)}%',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _attStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 28)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13)),
      ],
    );
  }

  void _showCreateAssignmentDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedSubject = 'Mathematics';
    final subjects = [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'English',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Create Assignment',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withAlpha(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withAlpha(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: subjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      setDialogState(() => selectedSubject = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withAlpha(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final assignment = {
                  'title': title,
                  'subject': selectedSubject,
                  'dueDate':
                      DateTime.now().add(const Duration(days: 7)).toString().substring(0, 10),
                  'description': descController.text.trim(),
                  'submissions': 0,
                  'total': 35,
                };
                setState(() {
                  (_schoolData['assignments'] as List).add(assignment);
                });
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReportCard() async {
    final students =
        List<Map<String, dynamic>>.from(_schoolData['students'] ?? []);
    if (students.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        content: const Row(
          children: [
            CircularProgressIndicator(color: Colors.deepPurpleAccent),
            SizedBox(width: 20),
            Text('Generating report...',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final student = students.first;
    final response = await AiService.sendMessageToTutor(
      "Generate a personalized student report card for ${student['name']}. "
      "Class: ${student['class']}, Marks: ${student['marks']}%, "
      "Attendance: ${student['attendance']}%, Behavior: ${student['behavior']}. "
      "Include strengths, areas for improvement, and encouragement. Keep it concise.",
    );

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Report: ${student['name']}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(response,
              style: const TextStyle(color: Colors.white70, height: 1.5)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
