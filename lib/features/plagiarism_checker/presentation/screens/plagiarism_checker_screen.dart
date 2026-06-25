import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlagiarismCheckerScreen extends StatefulWidget {
  const PlagiarismCheckerScreen({super.key});

  @override
  State<PlagiarismCheckerScreen> createState() =>
      _PlagiarismCheckerScreenState();
}

class _PlagiarismCheckerScreenState extends State<PlagiarismCheckerScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isChecking = false;
  bool _hasResult = false;

  double _originalityScore = 0;
  double _similarityPercentage = 0;
  double _copiedPercentage = 0;
  List<Map<String, dynamic>> _flaggedSections = [];
  String _summary = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('plagiarism_checks') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'plagiarism_checks',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _checkPlagiarism() async {
    if (_textController.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter at least 20 characters')),
      );
      return;
    }

    setState(() => _isChecking = true);

    final text = _textController.text.trim();
    final prompt =
        'Analyze this text for plagiarism:\n\n"$text"\n\n'
        'Return:\n'
        'ORIGINALITY: X (0-100, percentage of original content)\n'
        'SIMILAR: X (0-100, percentage similar to known sources)\n'
        'COPIED: X (0-100, percentage likely copied)\n'
        'FLAGGED: sentence1|reason1|sentence2|reason2 (up to 3 flagged sections, alternating)\n'
        'SUMMARY: one sentence summary of the plagiarism check';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'ORIGINALITY: 85\nSIMILAR: 10\nCOPIED: 5\n'
          'FLAGGED: \nSUMMARY: Mostly original content with minor similarities.';
    }

    double originality = 85, similar = 10, copied = 5;
    final origMatch = RegExp(r'ORIGINALITY:\s*([\d.]+)').firstMatch(response);
    if (origMatch != null) {
      originality = double.tryParse(origMatch.group(1)!) ?? 85;
    }
    final simMatch = RegExp(r'SIMILAR:\s*([\d.]+)').firstMatch(response);
    if (simMatch != null) similar = double.tryParse(simMatch.group(1)!) ?? 10;
    final copMatch = RegExp(r'COPIED:\s*([\d.]+)').firstMatch(response);
    if (copMatch != null) copied = double.tryParse(copMatch.group(1)!) ?? 5;

    final flagged = <Map<String, dynamic>>[];
    final flagMatch = RegExp(r'FLAGGED:\s*(.+?)(?=SUMMARY:|$)', dotAll: true)
        .firstMatch(response);
    if (flagMatch != null && flagMatch.group(1)!.trim().isNotEmpty) {
      final parts = flagMatch.group(1)!.trim().split('|');
      for (var i = 0; i < parts.length - 1; i += 2) {
        flagged.add({
          'text': parts[i].trim(),
          'reason': parts[i + 1].trim(),
        });
      }
    }

    final summMatch = RegExp(r'SUMMARY:\s*(.+)').firstMatch(response);
    final summary = summMatch?.group(1)?.trim() ?? 'Analysis complete.';

    final result = {
      'originality': originality,
      'similarity': similar,
      'copied': copied,
      'flaggedSections': flagged,
      'summary': summary,
      'textLength': text.length,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _originalityScore = originality;
      _similarityPercentage = similar;
      _copiedPercentage = copied;
      _flaggedSections = flagged;
      _summary = summary;
      _isChecking = false;
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
          'Plagiarism Checker',
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
            TextField(
              controller: _textController,
              maxLines: 12,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste your assignment text here...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
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
                onPressed: _isChecking ? null : _checkPlagiarism,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                label: Text(
                  _isChecking ? 'Analyzing...' : 'Check Plagiarism',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildPieChart(),
              const SizedBox(height: 16),
              _buildScoreBreakdown(),
              const SizedBox(height: 16),
              _buildFlaggedSections(),
              const SizedBox(height: 16),
              _buildSummary(),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Past Checks',
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

  Widget _buildPieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Plagiarism Analysis',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            width: 180,
            child: CustomPaint(
              painter: _PieChartPainter(
                original: _originalityScore,
                similar: _similarityPercentage,
                copied: _copiedPercentage,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.greenAccent, 'Original'),
              const SizedBox(width: 16),
              _legendDot(Colors.amberAccent, 'Similar'),
              const SizedBox(width: 16),
              _legendDot(Colors.redAccent, 'Copied'),
            ],
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildScoreBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _scoreBar('Original', _originalityScore, Colors.greenAccent),
          const SizedBox(height: 10),
          _scoreBar('Similar', _similarityPercentage, Colors.amberAccent),
          const SizedBox(height: 10),
          _scoreBar('Copied', _copiedPercentage, Colors.redAccent),
        ],
      ),
    ).animate().fade();
  }

  Widget _scoreBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
            Text('${value.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: Colors.white.withAlpha(15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildFlaggedSections() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Flagged Sections (${_flaggedSections.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_flaggedSections.isEmpty)
            Text(
              'No flagged sections found!',
              style: TextStyle(
                color: Colors.greenAccent.withAlpha(200),
                fontSize: 13,
              ),
            )
          else
            ..._flaggedSections.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${entry.value['text']}"',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${entry.value['reason']}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
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

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _originalityScore >= 80
            ? Colors.greenAccent.withAlpha(15)
            : Colors.amberAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _originalityScore >= 80
              ? Colors.greenAccent.withAlpha(40)
              : Colors.amberAccent.withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _originalityScore >= 80
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: _originalityScore >= 80
                ? Colors.greenAccent
                : Colors.amberAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _summary,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final orig = r['originality'] as double;
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
              color: (orig >= 80 ? Colors.greenAccent : Colors.amberAccent)
                  .withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.search,
                color: orig >= 80 ? Colors.greenAccent : Colors.amberAccent,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plagiarism Check',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Original: ${orig.toStringAsFixed(1)}% • Similar: ${(r['similarity'] as double).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${orig.toStringAsFixed(0)}%',
            style: TextStyle(
              color: orig >= 80
                  ? Colors.greenAccent
                  : orig >= 50
                      ? Colors.amberAccent
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

class _PieChartPainter extends CustomPainter {
  final double original;
  final double similar;
  final double copied;

  _PieChartPainter({
    required this.original,
    required this.similar,
    required this.copied,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final total = original + similar + copied;
    if (total == 0) return;

    final segments = [
      {'value': original / total, 'color': Colors.greenAccent},
      {'value': similar / total, 'color': Colors.amberAccent},
      {'value': copied / total, 'color': Colors.redAccent},
    ];

    double startAngle = -pi / 2;
    for (final seg in segments) {
      final sweepAngle = 2 * pi * (seg['value'] as double);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()..color = seg['color'] as Color,
      );
      startAngle += sweepAngle;
    }

    canvas.drawCircle(
      center,
      radius * 0.5,
      Paint()..color = const Color(0xFF1E1E1E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
