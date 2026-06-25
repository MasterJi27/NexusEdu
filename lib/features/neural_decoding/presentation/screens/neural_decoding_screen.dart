import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NeuralDecodingScreen extends StatefulWidget {
  const NeuralDecodingScreen({super.key});

  @override
  State<NeuralDecodingScreen> createState() => _NeuralDecodingScreenState();
}

class _NeuralDecodingScreenState extends State<NeuralDecodingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<String> _decodings = [];
  String? _currentLesson;
  String? _selectedChip;
  bool _isDecoding = false;
  Timer? _waveTimer;
  double _wavePhase = 0;

  static const List<String> _suggestedConcepts = [
    'Quantum Entanglement',
    'Photosynthesis',
    'Neural Networks',
    'CRISPR-Cas9',
    'Economic Inflation',
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _waveTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() => _wavePhase += 0.05);
    });
    _loadDecodings();
  }

  Future<void> _loadDecodings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('neural_decodings') ?? [];
    setState(() => _decodings.addAll(saved));
  }

  Future<void> _saveDecodings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('neural_decodings', _decodings);
  }

  Future<void> _decodeThought(String input) async {
    if (input.isEmpty) return;
    setState(() => _isDecoding = true);

    final result = await AiService.generateCurriculum(input);

    if (!mounted) return;
    setState(() {
      _isDecoding = false;
      _currentLesson = result;
      _decodings.insert(0, input);
      if (_decodings.length > 20) _decodings.removeLast();
    });
    _saveDecodings();
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Neural Decoding',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrainWaveVisualizer(),
            const SizedBox(height: 24),
            _buildInputSection(),
            const SizedBox(height: 20),
            if (_isDecoding) _buildDecodingLoader(),
            if (_currentLesson != null && !_isDecoding) _buildLessonCard(),
            const SizedBox(height: 24),
            _buildDecodingLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainWaveVisualizer() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.withAlpha(30),
              Colors.teal.withAlpha(15),
            ],
          ),
          border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(double.infinity, 180),
                painter: _BrainWavePainter(
                  phase: _wavePhase,
                  color: Colors.deepPurpleAccent,
                  amplitude: 1.2,
                ),
              ),
              CustomPaint(
                size: const Size(double.infinity, 180),
                painter: _BrainWavePainter(
                  phase: _wavePhase + 1.5,
                  color: Colors.tealAccent,
                  amplitude: 0.8,
                ),
              ),
              Positioned(
                top: 12,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NEURAL ACTIVE',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Text(
                  'fNIRS Signal',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Text(
                  'θ: ${(_wavePhase % 6.28).toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    color: Colors.white.withAlpha(80),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().slideY(begin: -0.1);
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What concept are you thinking about?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Type a topic or select a suggestion below',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withAlpha(120),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter a concept...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.deepPurpleAccent.withAlpha(120),
                ),
              ),
              prefixIcon: Icon(
                Icons.psychology,
                color: Colors.deepPurpleAccent.withAlpha(180),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedConcepts.map((concept) {
              final selected = _selectedChip == concept;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedChip = concept);
                  _textController.text = concept;
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.deepPurpleAccent.withAlpha(50)
                        : Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(25),
                    ),
                  ),
                  child: Text(
                    concept,
                    style: TextStyle(
                      color:
                          selected ? Colors.deepPurpleAccent : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDecoding
                  ? null
                  : () => _decodeThought(_textController.text.trim()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.bolt),
              label: Text(
                _isDecoding ? 'Decoding...' : 'Decode Thought',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildDecodingLoader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(60)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.deepPurpleAccent),
          const SizedBox(height: 16),
          Text(
            'Reading neural patterns...',
            style: TextStyle(
              color: Colors.deepPurpleAccent.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildLessonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withAlpha(25),
            Colors.deepPurple.withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.tealAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Decoded Neural Lesson',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentLesson!,
            style: TextStyle(
              color: Colors.white.withAlpha(210),
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildDecodingLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Concept Detection Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (_decodings.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() => _decodings.clear());
                  _saveDecodings();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(40)),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_decodings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.history, size: 40, color: Colors.white.withAlpha(50)),
                const SizedBox(height: 8),
                Text(
                  'No decodings yet',
                  style: TextStyle(
                    color: Colors.white.withAlpha(100),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_decodings.length, (index) {
            final decoding = _decodings[index];
            final time = DateTime.now()
                .subtract(Duration(hours: index))
                .toIso8601String()
                .substring(11, 16);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withAlpha(25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: Colors.deepPurpleAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          decoding,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Decoded at $time',
                          style: TextStyle(
                            color: Colors.white.withAlpha(80),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.tealAccent,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    ).animate().fade(delay: 200.ms);
  }
}

class _BrainWavePainter extends CustomPainter {
  final double phase;
  final Color color;
  final double amplitude;

  _BrainWavePainter({
    required this.phase,
    required this.color,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(60)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withAlpha(20)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    final glowPath = Path();
    final midY = size.height / 2;
    final spacing = 20.0;

    for (double x = 0; x < size.width; x += 1) {
      final wave = sin((x / spacing) + phase) * 20 * amplitude;
      final sharp = sin((x / (spacing * 0.6)) + phase * 1.7) * 12 * amplitude;
      final y = midY + wave + sharp;

      if (x == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
    }

    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(path, paint);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withAlpha(30),
          color.withAlpha(5),
          color.withAlpha(30),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _BrainWavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
