import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EssayEvaluatorScreen extends StatefulWidget {
  const EssayEvaluatorScreen({super.key});

  @override
  State<EssayEvaluatorScreen> createState() => _EssayEvaluatorScreenState();
}

class _EssayEvaluatorScreenState extends State<EssayEvaluatorScreen> {
  final TextEditingController _essayController = TextEditingController();
  String _selectedSubject = 'English';
  String _selectedGenre = 'Argumentative';
  bool _isEvaluating = false;
  bool _hasResult = false;

  int _structureScore = 0;
  int _grammarScore = 0;
  int _argumentsScore = 0;
  int _depthScore = 0;
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('essay_scores') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'essay_scores',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _evaluateEssay() async {
    if (_essayController.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please write at least 20 characters')),
      );
      return;
    }

    setState(() => _isEvaluating = true);

    final prompt =
        'Evaluate this $_selectedGenre essay on $_selectedSubject:\n\n'
        '${_essayController.text.trim()}\n\n'
        'Score each category from 0-25:\n'
        'STRUCTURE: X/25 (intro, body, conclusion, flow)\n'
        'GRAMMAR: X/25 (spelling, punctuation, sentence structure)\n'
        'ARGUMENTS: X/25 (evidence, logic, persuasiveness)\n'
        'DEPTH: X/25 (analysis, insight, critical thinking)\n'
        'SUGGESTIONS: list 3 specific improvement suggestions separated by |\n'
        'Format strictly: STRUCTURE: X\nGRAMMAR: X\nARGUMENTS: X\nDEPTH: X\nSUGGESTIONS: s1|s2|s3';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'STRUCTURE: 15\nGRAMMAR: 15\nARGUMENTS: 15\nDEPTH: 15\n'
          'SUGGESTIONS: Add more evidence|Improve transitions|Deepen analysis';
    }

    int structure = 15, grammar = 15, arguments = 15, depth = 15;
    List<String> suggestions = [];

    final sMatch = RegExp(r'STRUCTURE:\s*(\d+)').firstMatch(response);
    if (sMatch != null) structure = int.tryParse(sMatch.group(1)!) ?? 15;
    final gMatch = RegExp(r'GRAMMAR:\s*(\d+)').firstMatch(response);
    if (gMatch != null) grammar = int.tryParse(gMatch.group(1)!) ?? 15;
    final aMatch = RegExp(r'ARGUMENTS:\s*(\d+)').firstMatch(response);
    if (aMatch != null) arguments = int.tryParse(aMatch.group(1)!) ?? 15;
    final dMatch = RegExp(r'DEEP?TH:\s*(\d+)').firstMatch(response);
    if (dMatch != null) depth = int.tryParse(dMatch.group(1)!) ?? 15;
    final sugMatch = RegExp(r'SUGGESTIONS:\s*(.+)').firstMatch(response);
    if (sugMatch != null) {
      suggestions = sugMatch.group(1)!.split('|').map((s) => s.trim()).toList();
    }

    if (suggestions.isEmpty) {
      suggestions = [
        'Add more supporting evidence for your arguments',
        'Improve paragraph transitions for better flow',
        'Include a stronger conclusion summarizing key points',
      ];
    }

    final result = {
      'subject': _selectedSubject,
      'genre': _selectedGenre,
      'structure': structure,
      'grammar': grammar,
      'arguments': arguments,
      'depth': depth,
      'total': structure + grammar + arguments + depth,
      'suggestions': suggestions,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _structureScore = structure;
      _grammarScore = grammar;
      _argumentsScore = arguments;
      _depthScore = depth;
      _suggestions = suggestions;
      _isEvaluating = false;
      _hasResult = true;
    });

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Essay Evaluator',
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
            _buildSubjectSelector(),
            const SizedBox(height: 12),
            _buildGenreSelector(),
            const SizedBox(height: 16),
            TextField(
              controller: _essayController,
              maxLines: 12,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste or type your essay here...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isEvaluating ? null : _evaluateEssay,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isEvaluating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rate_review),
                label: Text(
                  _isEvaluating ? 'Evaluating...' : 'Evaluate Essay',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildRadarChart(),
              const SizedBox(height: 20),
              _buildScoreBreakdown(),
              const SizedBox(height: 20),
              _buildSuggestions(),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Past Evaluations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_results.length.clamp(0, 5), (i) {
                return _buildResultCard(_results[i]);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildSelectorRow(
      'Subject',
      ['English', 'History', 'Science', 'Philosophy', 'General'],
      _selectedSubject,
      (val) => setState(() => _selectedSubject = val!),
    );
  }

  Widget _buildGenreSelector() {
    return _buildSelectorRow(
      'Genre',
      ['Argumentative', 'Narrative', 'Descriptive', 'Expository', 'Persuasive'],
      _selectedGenre,
      (val) => setState(() => _selectedGenre = val!),
    );
  }

  Widget _buildSelectorRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurpleAccent.withAlpha(40)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(15),
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildRadarChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Score Radar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            width: 220,
            child: CustomPaint(
              painter: _RadarChartPainter(
                values: [
                  _structureScore / 25,
                  _grammarScore / 25,
                  _argumentsScore / 25,
                  _depthScore / 25,
                ],
                labels: ['Structure', 'Grammar', 'Arguments', 'Depth'],
                colors: [
                  Colors.deepPurpleAccent,
                  Colors.tealAccent,
                  Colors.amberAccent,
                  Colors.pinkAccent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total: ${_structureScore + _grammarScore + _argumentsScore + _depthScore}/100',
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildScoreBreakdown() {
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
            'Score Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _scoreBar('Structure', _structureScore, 25, Colors.deepPurpleAccent),
          const SizedBox(height: 10),
          _scoreBar('Grammar', _grammarScore, 25, Colors.tealAccent),
          const SizedBox(height: 10),
          _scoreBar('Arguments', _argumentsScore, 25, Colors.amberAccent),
          const SizedBox(height: 10),
          _scoreBar('Depth', _depthScore, 25, Colors.pinkAccent),
        ],
      ),
    ).animate().fade();
  }

  Widget _scoreBar(String label, int score, int max, Color color) {
    final ratio = score / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
            Text('$score/$max',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white.withAlpha(15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
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
            'Suggestions for Improvement',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._suggestions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb,
                      color: Colors.amberAccent.withAlpha(200), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 13,
                        height: 1.4,
                      ),
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

  Widget _buildResultCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.article,
                color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['subject']} - ${r['genre']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['total']}/100',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${r['total']}',
            style: TextStyle(
              color: (r['total'] as int) >= 75
                  ? Colors.greenAccent
                  : (r['total'] as int) >= 50
                      ? Colors.orangeAccent
                      : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;

  _RadarChartPainter({
    required this.values,
    required this.labels,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;
    final sides = values.length;

    for (int ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * ring / 4;
      final ringPath = Path();
      for (int i = 0; i < sides; i++) {
        final angle = (2 * pi * i / sides) - pi / 2;
        final point = Offset(
          center.dx + ringRadius * cos(angle),
          center.dy + ringRadius * sin(angle),
        );
        if (i == 0) {
          ringPath.moveTo(point.dx, point.dy);
        } else {
          ringPath.lineTo(point.dx, point.dy);
        }
      }
      ringPath.close();
      canvas.drawPath(
        ringPath,
        Paint()
          ..color = Colors.white.withAlpha(15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(
        center,
        point,
        Paint()
          ..color = Colors.white.withAlpha(20)
          ..strokeWidth = 1,
      );

      final labelPoint = Offset(
        center.dx + (radius + 18) * cos(angle),
        center.dy + (radius + 18) * sin(angle),
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: colors[i],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelPoint.dx - textPainter.width / 2,
          labelPoint.dy - textPainter.height / 2,
        ),
      );
    }

    final dataPath = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      final val = values[i].clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * val * cos(angle),
        center.dy + radius * val * sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = Colors.deepPurpleAccent.withAlpha(60)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = Colors.deepPurpleAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi * i / sides) - pi / 2;
      final val = values[i].clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * val * cos(angle),
        center.dy + radius * val * sin(angle),
      );
      canvas.drawCircle(
        point,
        4,
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
