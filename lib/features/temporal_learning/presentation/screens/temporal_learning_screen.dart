import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';

class TemporalLearningScreen extends StatefulWidget {
  const TemporalLearningScreen({super.key});

  @override
  State<TemporalLearningScreen> createState() => _TemporalLearningScreenState();
}

class _TemporalLearningScreenState extends State<TemporalLearningScreen>
    with TickerProviderStateMixin {
  static const int _totalDuration = 300;
  static const int _microLessonDuration = 30;
  static const double _perceivedMultiplier = 6.0;

  late AnimationController _countdownController;
  late AnimationController _waveController;
  int _realElapsed = 0;
  int _currentLessonIndex = 0;
  bool _isRunning = false;
  bool _isComplete = false;
  int _flowScore = 0;
  Timer? _timer;

  final List<String> _concepts = [
    'Quantum Entanglement',
    'Photosynthesis',
    'Binary Trees',
    'Neural Networks',
    'Black Holes',
    'CRISPR Gene Editing',
    'Theory of Relativity',
    'Blockchain',
    'Cognitive Biases',
    'Entropy',
  ];

  final List<Map<String, String>> _completedLessons = [];

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalDuration),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _startSession() {
    setState(() {
      _isRunning = true;
      _isComplete = false;
      _realElapsed = 0;
      _currentLessonIndex = 0;
      _completedLessons.clear();
    });
    _countdownController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _realElapsed++;
        if (_realElapsed % _microLessonDuration == 0 &&
            _currentLessonIndex < _concepts.length - 1) {
          _completedLessons.add({
            'concept': _concepts[_currentLessonIndex],
            'time': DateTime.now().toIso8601String(),
          });
          _currentLessonIndex++;
        }
        if (_realElapsed >= _totalDuration) {
          _completeSession();
        }
      });
    });
  }

  void _completeSession() {
    _timer?.cancel();
    _countdownController.reset();
    if (_currentLessonIndex < _concepts.length) {
      _completedLessons.add({
        'concept': _concepts[_currentLessonIndex],
        'time': DateTime.now().toIso8601String(),
      });
    }
    _flowScore = 50 + (_completedLessons.length * 5);
    _flowScore = _flowScore.clamp(0, 100);

    final session = {
      'date': DateTime.now().toIso8601String(),
      'realSeconds': _totalDuration,
      'perceivedSeconds': _totalDuration * _perceivedMultiplier,
      'conceptsCovered': _completedLessons.length,
      'flowScore': _flowScore,
    };
    _saveSession(session);

    setState(() {
      _isRunning = false;
      _isComplete = true;
    });
  }

  Future<void> _saveSession(Map<String, dynamic> session) async {
    final settings = AppSettings.instance;
    final existing = settings.cachedNotes
        .where((n) => n['type'] == 'temporal_sessions')
        .toList();
    final sessions = existing.isNotEmpty
        ? List<Map<String, dynamic>>.from(
            json.decode(existing.first['data'] ?? '[]'))
        : <Map<String, dynamic>>[];
    sessions.insert(0, session);
    final updated = [
      {'type': 'temporal_sessions', 'data': json.encode(sessions)}
    ];
    await settings.saveCachedNotes(updated);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  int get _realSeconds => _realElapsed;
  int get _perceivedSeconds => (_realElapsed * _perceivedMultiplier).round();
  int get _remaining => _totalDuration - _realElapsed;
  double get _progress => _realElapsed / _totalDuration;

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Time Dilation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isComplete ? _buildReport() : _buildSession(),
    );
  }

  Widget _buildSession() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTimeDisplay(),
          const SizedBox(height: 32),
          _buildCircularTimer(),
          const SizedBox(height: 32),
          _buildBinauralWaves(),
          const SizedBox(height: 32),
          if (_isRunning) _buildMicroLesson(),
          const SizedBox(height: 32),
          if (!_isRunning)
            _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimeColumn('Real Time', _formatTime(_realSeconds), Colors.white70),
          Container(width: 1, height: 40, color: Colors.white.withAlpha(20)),
          _buildTimeColumn('Perceived Time', _formatTime(_perceivedSeconds), Colors.deepPurpleAccent),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String time, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(time,
          style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900, color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularTimer() {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _CountdownPainter(
          progress: _progress,
          remaining: _remaining,
          color: Colors.deepPurpleAccent,
        ),
      ),
    );
  }

  Widget _buildBinauralWaves() {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        children: [
          const Text('Binaural Beats', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _BinauralWavePainter(
                    progress: _waveController.value,
                    isRunning: _isRunning,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroLesson() {
    final concept = _concepts[_currentLessonIndex];
    final lessonProgress = (_realElapsed % _microLessonDuration) / _microLessonDuration;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withAlpha(30),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MICRO-LESSON ${_currentLessonIndex + 1}',
            style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Text(
            concept,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: lessonProgress,
              backgroundColor: Colors.white.withAlpha(20),
              color: Colors.deepPurpleAccent,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_microLessonDuration - (_realElapsed % _microLessonDuration)}s remaining',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton.icon(
      onPressed: _startSession,
      icon: const Icon(Icons.play_circle_fill, size: 28),
      label: const Text('Begin Time Dilation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
      ),
    );
  }

  Widget _buildReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.timelapse, size: 64, color: Colors.deepPurpleAccent),
          const SizedBox(height: 16),
          const Text('Time Dilation Complete',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Column(
              children: [
                _buildReportRow('Concepts Covered', '${_completedLessons.length}'),
                const Divider(color: Colors.white12),
                _buildReportRow('Real Time', _formatTime(_totalDuration)),
                const Divider(color: Colors.white12),
                _buildReportRow('Perceived Time', _formatTime(_totalDuration * _perceivedMultiplier.toInt())),
                const Divider(color: Colors.white12),
                _buildReportRow('Flow Score', '$_flowScore/100'),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _flowScore / 100,
                    backgroundColor: Colors.white.withAlpha(20),
                    color: Colors.deepPurpleAccent,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_completedLessons.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(10)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.deepPurpleAccent),
                    const SizedBox(width: 12),
                    Text(_completedLessons[i]['concept'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isComplete = false;
                _completedLessons.clear();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Start New Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  final int remaining;
  final Color color;

  _CountdownPainter({required this.progress, required this.remaining, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi * progress,
        colors: [color.withAlpha(150), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

    final labelPainter = TextPainter(
      text: TextSpan(text: 'REMAINING', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(center.dx - labelPainter.width / 2, center.dy + 24));
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter old) => old.progress != progress;
}

class _BinauralWavePainter extends CustomPainter {
  final double progress;
  final bool isRunning;

  _BinauralWavePainter({required this.progress, required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRunning) return;
    final leftFreq = 2.0;
    final rightFreq = 2.4;
    final amplitude = size.height / 3;
    final centerY = size.height / 2;

    final leftPaint = Paint()
      ..color = Colors.cyanAccent.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final rightPaint = Paint()
      ..color = Colors.deepPurpleAccent.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final pathLeft = Path();
    final pathRight = Path();
    final phase = progress * 2 * pi;

    for (double x = 0; x <= size.width; x++) {
      final t = x / size.width;
      final leftY = centerY - amplitude + sin(t * leftFreq * 4 * pi + phase) * (amplitude * 0.5);
      final rightY = centerY + amplitude + sin(t * rightFreq * 4 * pi + phase + 0.5) * (amplitude * 0.5);

      if (x == 0) {
        pathLeft.moveTo(x, leftY);
        pathRight.moveTo(x, rightY);
      } else {
        pathLeft.lineTo(x, leftY);
        pathRight.lineTo(x, rightY);
      }
    }

    canvas.drawPath(pathLeft, leftPaint);
    canvas.drawPath(pathRight, rightPaint);

    final labelPaint = TextPainter(
      text: const TextSpan(text: 'L', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      textDirection: TextDirection.ltr,
    );
    labelPaint.layout();
    labelPaint.paint(canvas, const Offset(8, 4));

    final labelRPaint = TextPainter(
      text: const TextSpan(text: 'R', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11)),
      textDirection: TextDirection.ltr,
    );
    labelRPaint.layout();
    labelRPaint.paint(canvas, Offset(8, size.height - 16));
  }

  @override
  bool shouldRepaint(covariant _BinauralWavePainter old) => old.progress != progress || old.isRunning != isRunning;
}
