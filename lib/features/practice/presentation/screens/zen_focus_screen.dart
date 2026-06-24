import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math';

class ZenFocusScreen extends StatefulWidget {
  const ZenFocusScreen({super.key});

  @override
  State<ZenFocusScreen> createState() => _ZenFocusScreenState();
}

class _ZenFocusScreenState extends State<ZenFocusScreen> {
  bool _isPlaying = false;
  int _secondsRemaining = 25 * 60; // 25 minutes
  Timer? _timer;

  void _toggleTimer() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_secondsRemaining > 0) {
            setState(() => _secondsRemaining--);
          } else {
            _timer?.cancel();
            setState(() => _isPlaying = false);
          }
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    int m = _secondsRemaining ~/ 60;
    int s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Deep ambient dark
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text('Zen Focus Mode', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient Background Blur
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A1B3D), Color(0xFF0F0F1A), Color(0xFF1B2A3D)],
                ),
              ),
            ),
          ),
          
          // Simulated Floating Particles
          ...List.generate(15, (index) => _buildParticle(index)),
          
          // Glassmorphism Blur Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.black.withAlpha(20)),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pomodoro Session', style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 2)),
                  const SizedBox(height: 48),
                  
                  // Circular Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: CircularProgressIndicator(
                          value: _secondsRemaining / (25 * 60),
                          strokeWidth: 8,
                          color: Colors.tealAccent,
                          backgroundColor: Colors.white.withAlpha(20),
                        ),
                      ).animate(
                        onPlay: (controller) => controller.repeat(reverse: true),
                        target: _isPlaying ? 1 : 0,
                      ).scaleXY(end: 1.05, duration: 2.seconds),
                      
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 64),
                  
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _secondsRemaining = 25 * 60;
                            _isPlaying = false;
                            _timer?.cancel();
                          });
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white70, size: 36),
                      ),
                      const SizedBox(width: 32),
                      GestureDetector(
                        onTap: _toggleTimer,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isPlaying ? Colors.redAccent.withAlpha(50) : Colors.tealAccent.withAlpha(50),
                            border: Border.all(color: _isPlaying ? Colors.redAccent : Colors.tealAccent, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: _isPlaying ? Colors.redAccent.withAlpha(50) : Colors.tealAccent.withAlpha(50),
                                blurRadius: 20,
                              )
                            ],
                          ),
                          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48),
                        ),
                      ),
                      const SizedBox(width: 32),
                      IconButton(
                        onPressed: () {}, // Skip mock
                        icon: const Icon(Icons.skip_next, color: Colors.white70, size: 36),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 64),
                  
                  // Mock Media Player (Lo-Fi)
                  Container(
                    width: 250,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.headphones, color: Colors.tealAccent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lofi Study Beats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('ChilledCow', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.graphic_eq, color: Colors.white70),
                      ],
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(),
                    target: _isPlaying ? 1 : 0,
                  ).shimmer(duration: 3.seconds, color: Colors.white.withAlpha(50)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticle(int index) {
    final rand = Random(index);
    final size = rand.nextDouble() * 20 + 10;
    return Positioned(
      left: rand.nextDouble() * 400,
      top: rand.nextDouble() * 800,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(rand.nextInt(30) + 10),
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(reverse: true),
      ).moveY(
        begin: 0,
        end: rand.nextDouble() * 100 - 50,
        duration: Duration(seconds: rand.nextInt(3) + 3),
        curve: Curves.easeInOut,
      ).fade(duration: 2.seconds),
    );
  }
}
