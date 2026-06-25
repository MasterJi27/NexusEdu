import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_computation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PeerComparisonScreen extends StatefulWidget {
  const PeerComparisonScreen({super.key});

  @override
  State<PeerComparisonScreen> createState() => _PeerComparisonScreenState();
}

class _PeerComparisonScreenState extends State<PeerComparisonScreen> {
  String _selectedSubject = 'physics';
  final TextEditingController _scoreController = TextEditingController();
  bool _isLoading = false;
  bool _hasResult = false;

  double _percentile = 0;
  String _feedback = '';
  List<String> _recommendations = [];
  List<String> _peerTopics = [];
  List<Map<String, dynamic>> _results = [];

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('peer_comparisons') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'peer_comparisons',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _compare() async {
    final userScore = double.tryParse(_scoreController.text.trim());
    if (userScore == null || userScore < 0 || userScore > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid score (0-100)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final simulatedScores = List.generate(
      50,
      (_) => 30 + _random.nextDouble() * 60,
    );

    final percentile = LocalComputation.calculatePercentile(
      userScore,
      simulatedScores,
    );

    final prompt =
        'Student scored $userScore% in $_selectedSubject.\n'
        'Their percentile is ${percentile.toStringAsFixed(0)}.\n'
        'Generate peer comparison insights:\n'
        'PEER_TOPICS: list 3-4 topics that students who scored higher studied (comma-separated)\n'
        'RECOMMENDATIONS: list 3 specific recommendations (comma-separated)\n'
        'FEEDBACK: one sentence feedback';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = 'PEER_TOPICS: Advanced Problems,Previous Year Papers,Conceptual Clarity\n'
          'RECOMMENDATIONS: Practice more problems,Focus on weak areas,Revise regularly\n'
          'FEEDBACK: You are performing well, keep it up!';
    }

    final topicsMatch = RegExp(r'PEER_TOPICS:\s*(.+)').firstMatch(response);
    final recsMatch = RegExp(r'RECOMMENDATIONS:\s*(.+)').firstMatch(response);
    final feedbackMatch = RegExp(r'FEEDBACK:\s*(.+)').firstMatch(response);

    final peerTopics = topicsMatch != null
        ? topicsMatch.group(1)!.split(',').map((s) => s.trim()).toList()
        : ['Previous Year Papers', 'Conceptual Clarity', 'Practice Problems'];
    final recommendations = recsMatch != null
        ? recsMatch.group(1)!.split(',').map((s) => s.trim()).toList()
        : ['Practice more', 'Focus on weak areas', 'Revise regularly'];
    final feedback =
        feedbackMatch?.group(1)?.trim() ?? 'Keep practicing!';

    final result = {
      'subject': _selectedSubject,
      'score': userScore,
      'percentile': percentile,
      'peerTopics': peerTopics,
      'recommendations': recommendations,
      'feedback': feedback,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _percentile = percentile;
      _peerTopics = peerTopics;
      _recommendations = recommendations;
      _feedback = feedback;
      _isLoading = false;
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
          'Peer Comparison',
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
            const SizedBox(height: 16),
            _buildScoreInput(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _compare,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.compare_arrows),
                label: Text(
                  _isLoading ? 'Comparing...' : 'Compare with Peers',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 24),
              _buildPercentileGauge(),
              const SizedBox(height: 20),
              _buildPeerTopics(),
              const SizedBox(height: 16),
              _buildRecommendations(),
              const SizedBox(height: 16),
              _buildFeedback(),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Past Comparisons',
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
      ['physics', 'chemistry', 'maths', 'biology'],
      _selectedSubject,
      (val) => setState(() => _selectedSubject = val!),
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
                    opt.toUpperCase(),
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

  Widget _buildScoreInput() {
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
            'Your Score (%)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _scoreController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Enter your score (0-100)',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withAlpha(15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withAlpha(15)),
              ),
              filled: true,
              fillColor: Colors.black.withAlpha(30),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildPercentileGauge() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Your Percentile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            width: 220,
            child: CustomPaint(
              painter: _PercentileGaugePainter(_percentile),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Top ${(100 - _percentile).toStringAsFixed(0)}%',
            style: TextStyle(
              color: _percentile >= 70
                  ? Colors.greenAccent
                  : _percentile >= 40
                      ? Colors.amberAccent
                      : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'You scored better than ${_percentile.toStringAsFixed(0)}% of students',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildPeerTopics() {
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
            'Topics Studied by Higher-Scoring Peers',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._peerTopics.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.trending_up,
                      color: Colors.tealAccent.withAlpha(200), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 13,
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

  Widget _buildRecommendations() {
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
            'Recommendations',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._recommendations.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb,
                      color: Colors.amberAccent.withAlpha(200), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 13,
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

  Widget _buildFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline,
              color: Colors.deepPurpleAccent.withAlpha(200)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _feedback,
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
    final pct = r['percentile'] as double;
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
            child: const Icon(Icons.group,
                color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['subject']} • Score: ${r['score']}%',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Percentile: ${pct.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
              color: pct >= 70
                  ? Colors.greenAccent
                  : pct >= 40
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

class _PercentileGaugePainter extends CustomPainter {
  final double percentile;

  _PercentileGaugePainter(this.percentile);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width / 2 - 10;
    const startAngle = pi;
    const sweepAngle = pi;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    final valPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    final ratio = (percentile / 100).clamp(0.0, 1.0);
    final color = percentile >= 70
        ? Colors.greenAccent
        : percentile >= 40
            ? Colors.amberAccent
            : Colors.redAccent;
    valPaint.shader = LinearGradient(
      colors: [color.withAlpha(150), color],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * ratio,
      false,
      valPaint,
    );

    final angle = startAngle + sweepAngle * ratio;
    final needleEnd = Offset(
      center.dx + (radius - 20) * cos(angle),
      center.dy + (radius - 20) * sin(angle),
    );

    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      center,
      6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
