import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyllabusUniverseScreen extends StatefulWidget {
  const SyllabusUniverseScreen({super.key});

  @override
  State<SyllabusUniverseScreen> createState() => _SyllabusUniverseScreenState();
}

class _SyllabusUniverseScreenState extends State<SyllabusUniverseScreen>
    with TickerProviderStateMixin {
  final TextEditingController _syllabusController = TextEditingController();
  List<Map<String, dynamic>> _worlds = [];
  bool _isGenerating = false;
  String? _error;
  int? _selectedWorldIndex;

  late AnimationController _orbitController;
  late Animation<double> _orbitAnimation;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _orbitAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _orbitController, curve: Curves.linear),
    );
    _loadUniverse();
  }

  Future<void> _loadUniverse() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('syllabus_universe');
    if (saved != null) {
      setState(() {
        _worlds = saved
            .map((e) => Map<String, dynamic>.from(json.decode(e)))
            .toList();
      });
    }
  }

  Future<void> _saveUniverse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'syllabus_universe', _worlds.map((e) => json.encode(e)).toList());
  }

  Future<void> _generateUniverse(String syllabus) async {
    if (syllabus.isEmpty) return;
    setState(() {
      _isGenerating = true;
      _error = null;
      _selectedWorldIndex = null;
    });

    final result = await AiService.generateCurriculum(syllabus);

    if (!mounted) return;

    List<dynamic> parsed;
    try {
      parsed = json.decode(result) as List<dynamic>;
    } catch (_) {
      setState(() {
        _isGenerating = false;
        _error = 'Could not parse universe data. Try again.';
      });
      return;
    }

    setState(() {
      _isGenerating = false;
      _worlds = parsed
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (var i = 0; i < _worlds.length; i++) {
        _worlds[i]['angle'] = (2 * pi * i) / _worlds.length;
      }
    });
    _saveUniverse();
  }

  void _selectWorld(int index) {
    setState(() {
      _selectedWorldIndex = _selectedWorldIndex == index ? null : index;
    });
  }

  @override
  void dispose() {
    _syllabusController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Syllabus Universe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_worlds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _worlds.clear();
                  _selectedWorldIndex = null;
                });
                _saveUniverse();
              },
              tooltip: 'Reset Universe',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const SizedBox(height: 24),
            if (_isGenerating) _buildGeneratingIndicator(),
            if (_error != null) _buildErrorCard(),
            if (_worlds.isNotEmpty) ...[
              _buildUniverseLabel(),
              const SizedBox(height: 16),
              _buildOrbitView(),
              const SizedBox(height: 24),
              if (_selectedWorldIndex != null) _buildDetailPanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.public,
                  color: Colors.deepPurpleAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Syllabus Universe Generator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter a syllabus to generate an explorable universe of concepts',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withAlpha(120),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _syllabusController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Class 12 CBSE Physics',
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
                  color: Colors.tealAccent.withAlpha(120),
                ),
              ),
              prefixIcon: Icon(
                Icons.auto_stories,
                color: Colors.tealAccent.withAlpha(180),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () => _generateUniverse(
                      _syllabusController.text.trim()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.tealAccent.withAlpha(200),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.rocket_launch),
              label: const Text(
                'Generate Universe',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.08);
  }

  Widget _buildGeneratingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withAlpha(30),
            Colors.teal.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.tealAccent),
          const SizedBox(height: 16),
          Text(
            'Assembling your universe...',
            style: TextStyle(
              color: Colors.tealAccent.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildUniverseLabel() {
    return Row(
      children: [
        const Text(
          'Generated Universe',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_worlds.length} worlds',
            style: TextStyle(
              color: Colors.tealAccent.withAlpha(200),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrbitView() {
    return AnimatedBuilder(
      animation: _orbitAnimation,
      builder: (context, child) {
        return Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.withAlpha(20),
                Colors.transparent,
                Colors.teal.withAlpha(10),
              ],
            ),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Stack(
            children: [
              // Center sun
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Colors.tealAccent, Colors.deepPurpleAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withAlpha(50),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              // Orbiting worlds
              ...List.generate(_worlds.length, (index) {
                final world = _worlds[index];
                final total = _worlds.length;
                final baseAngle = (2 * pi * index) / total;
                final angle = baseAngle + _orbitAnimation.value;
                final radius = 70.0 + (index % 3) * 12.0;
                final x = (MediaQuery.of(context).size.width / 2) - 20 +
                    cos(angle) * radius;
                final y = 110 + sin(angle) * radius;

                return Positioned(
                  left: x - 28,
                  top: y - 28,
                  child: GestureDetector(
                    onTap: () => _selectWorld(index),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurpleAccent.withAlpha(150),
                                Colors.teal.withAlpha(100),
                              ],
                            ),
                            border: Border.all(
                              color: _selectedWorldIndex == index
                                  ? Colors.tealAccent
                                  : Colors.deepPurpleAccent.withAlpha(80),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withAlpha(40),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: angle,
                            child: Icon(
                              Icons.circle,
                              color: Colors.white.withAlpha(180),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 80,
                          child: Text(
                            world['title'] ?? 'World',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _selectedWorldIndex == index
                                  ? Colors.tealAccent
                                  : Colors.white.withAlpha(150),
                              fontSize: 11,
                              fontWeight: _selectedWorldIndex == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildDetailPanel() {
    final world = _worlds[_selectedWorldIndex!];
    final title = world['title'] ?? 'Unknown';
    final summary = world['summary'] ?? '';
    final difficulty = world['difficulty'] ?? 'Beginner';
    final minutes = world['estimatedMinutes'] ?? 30;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withAlpha(20),
            Colors.deepPurple.withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.tealAccent.withAlpha(40)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
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
                    Icons.explore,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: difficulty == 'Beginner'
                        ? Colors.green.withAlpha(30)
                        : difficulty == 'Intermediate'
                            ? Colors.orange.withAlpha(30)
                            : Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    difficulty,
                    style: TextStyle(
                      color: difficulty == 'Beginner'
                          ? Colors.greenAccent
                          : difficulty == 'Intermediate'
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              summary,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _buildSliderControl(
              'Gravity (Difficulty Pull)',
              Icons.speed,
              0.3,
              Colors.tealAccent,
            ),
            const SizedBox(height: 14),
            _buildSliderControl(
              'Temperature (Bloom Level)',
              Icons.thermostat,
              0.6,
              Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 14),
            _buildSliderControl(
              'Time Dilation',
              Icons.timer,
              0.5,
              Colors.amberAccent,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 16, color: Colors.white.withAlpha(120)),
                const SizedBox(width: 6),
                Text(
                  '~$minutes min',
                  style: TextStyle(color: Colors.white.withAlpha(150)),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.rocket, size: 16),
                  label: const Text('Explore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildSliderControl(
      String label, IconData icon, double initial, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setLocalState) => SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16),
                      activeTrackColor: color,
                      inactiveTrackColor: color.withAlpha(30),
                      thumbColor: color,
                    ),
                    child: Slider(
                      value: initial,
                      min: 0,
                      max: 1,
                      onChanged: (v) => setLocalState(() => initial = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(initial * 100).round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
