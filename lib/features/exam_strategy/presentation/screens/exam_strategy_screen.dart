import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';

class ExamStrategyScreen extends StatefulWidget {
  const ExamStrategyScreen({super.key});

  @override
  State<ExamStrategyScreen> createState() => _ExamStrategyScreenState();
}

class _ExamStrategyScreenState extends State<ExamStrategyScreen> {
  String _selectedExam = 'JEE';
  final TextEditingController _daysController = TextEditingController();
  final List<Map<String, dynamic>> _subjects = [{'name': '', 'marks': ''}];
  bool _isLoading = false;
  List<String> _dayPlan = [];
  List<Map<String, dynamic>> _chapterPriority = [];
  List<double> _timeAllocation = [];

  static const List<String> _examTypes = ['JEE', 'NEET', 'CBSE', 'Board', 'UPSC', 'State Exam'];

  @override
  void initState() {
    super.initState();
    _loadStrategies();
  }

  Future<void> _loadStrategies() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('exam_strategies');
    if (saved != null && saved.isNotEmpty) {
      final last = jsonDecode(saved.last) as Map<String, dynamic>;
      _selectedExam = last['exam'] ?? 'JEE';
      _daysController.text = last['days'] ?? '30';
    }
    setState(() {});
  }

  Future<void> _saveStrategy() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('exam_strategies') ?? [];
    history.add(jsonEncode({
      'exam': _selectedExam,
      'days': _daysController.text,
      'subjects': _subjects,
      'dayPlan': _dayPlan,
      'chapterPriority': _chapterPriority,
      'timeAllocation': _timeAllocation,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (history.length > 20) history.removeAt(0);
    await prefs.setStringList('exam_strategies', history);
  }

  Future<void> _generateStrategy() async {
    final days = int.tryParse(_daysController.text) ?? 30;
    final validSubjects = _subjects.where((s) => (s['name'] as String).isNotEmpty).toList();
    if (validSubjects.isEmpty) return;

    setState(() {
      _isLoading = true;
      _dayPlan = [];
      _chapterPriority = [];
      _timeAllocation = [];
    });

    final subjectsStr = validSubjects.map((s) => '${s["name"]}(${s["marks"]}m)').join(', ');
    final prompt = 'Create a study strategy for $_selectedExam in $days days.\n'
        'Subjects: $subjectsStr\n'
        'Provide: 1) Day-by-day plan (list of strings), '
        '2) Chapter priorities with name and priority (1-10), '
        '3) Time allocation percentages for each subject.\n'
        'Format as JSON: {"days": ["Day 1: ..."], "chapters": [{"name":"...", "priority":8}], '
        '"allocation": [30, 25, 25, 20]}';

    final response = await AiAgentService.callAgent('custom', {'prompt': prompt});

    final rng = Random();
    try {
      final jsonStr = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _dayPlan = (data['days'] as List<dynamic>? ?? []).cast<String>();
      _chapterPriority = (data['chapters'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((c) => {
        'name': c['name'] ?? 'Chapter',
        'priority': c['priority'] ?? (5 + rng.nextInt(5)),
      }).toList();
      final alloc = data['allocation'] as List<dynamic>?;
      _timeAllocation = alloc != null
          ? alloc.map<double>((a) => (a as num).toDouble()).toList()
          : List.generate(validSubjects.length, (_) => 100.0 / validSubjects.length);
    } catch (_) {
      _dayPlan = List.generate(min(days, 14), (i) => 'Day ${i + 1}: Revise ${validSubjects[i % validSubjects.length]["name"]} key topics');
      _chapterPriority = validSubjects.map<Map<String, dynamic>>((s) => {
        'name': s['name'],
        'priority': 5 + rng.nextInt(5),
      }).toList();
      _timeAllocation = List.generate(validSubjects.length, (_) => 100.0 / validSubjects.length);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _saveStrategy();
  }

  void _addSubject() {
    setState(() => _subjects.add({'name': '', 'marks': ''}));
  }

  void _removeSubject(int index) {
    if (_subjects.length > 1) {
      setState(() => _subjects.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Exam Strategy AI', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputSection(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _generateStrategy,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Strategy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          if (_dayPlan.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildDayPlan(),
            const SizedBox(height: 24),
            _buildChapterPriority(),
            const SizedBox(height: 24),
            _buildPieChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exam Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          const Text('Exam Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFF0F0F13), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(15))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExam,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withAlpha(150)),
                items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedExam = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Days Left', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. 30',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.deepPurpleAccent)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subjects & Marks', style: TextStyle(color: Colors.white70, fontSize: 12)),
              IconButton(
                onPressed: _addSubject,
                icon: const Icon(Icons.add_circle, color: Colors.deepPurpleAccent),
              ),
            ],
          ),
          ..._subjects.asMap().entries.map((entry) {
            final i = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (v) => _subjects[i]['name'] = v,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Subject',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (v) => _subjects[i]['marks'] = v,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Marks',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  if (_subjects.length > 1)
                    IconButton(
                      onPressed: () => _removeSubject(i),
                      icon: Icon(Icons.remove_circle, color: Colors.redAccent.withAlpha(180), size: 20),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildDayPlan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Day-by-Day Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._dayPlan.asMap().entries.map((entry) {
            final i = entry.key;
            final day = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F13),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(day, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13))),
                ],
              ),
            ).animate().fade(delay: Duration(milliseconds: i * 50));
          }),
        ],
      ),
    );
  }

  Widget _buildChapterPriority() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chapter Priority', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._chapterPriority.asMap().entries.map((entry) {
            final i = entry.key;
            final ch = entry.value;
            final priority = ch['priority'] as int;
            final color = priority >= 8 ? Colors.redAccent : priority >= 5 ? Colors.amberAccent : Colors.green;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Text(ch['name'] ?? '', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                    child: Text('$priority/10', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildPieChart() {
    final validSubjects = _subjects.where((s) => (s['name'] as String).isNotEmpty).toList();
    final colors = [Colors.deepPurpleAccent, Colors.cyanAccent, Colors.amberAccent, Colors.greenAccent, Colors.pinkAccent, Colors.orangeAccent];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Time Allocation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 180, height: 180,
              child: CustomPaint(
                painter: _PieChartPainter(_timeAllocation, colors),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: validSubjects.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final color = colors[i % colors.length];
              final pct = i < _timeAllocation.length ? _timeAllocation[i].toStringAsFixed(0) : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('${s["name"]} ($pct%)', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }
}

class _PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  _PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final total = data.fold<double>(0, (s, v) => s + v);
    if (total == 0) return;

    double startAngle = -pi / 2;
    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    canvas.drawCircle(center, radius * 0.5, Paint()..color = const Color(0xFF1E1E1E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
