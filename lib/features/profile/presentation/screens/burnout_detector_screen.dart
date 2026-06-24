import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class BurnoutDetectorScreen extends StatefulWidget {
  const BurnoutDetectorScreen({super.key});

  @override
  State<BurnoutDetectorScreen> createState() => _BurnoutDetectorScreenState();
}

class _BurnoutDetectorScreenState extends State<BurnoutDetectorScreen> {
  String _instruction = "Breathe In";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startBreathingCycle();
  }

  void _startBreathingCycle() {
    // Simple 4-second box breathing cycle
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_instruction == "Breathe In") {
          _instruction = "Hold";
        } else if (_instruction == "Hold") {
          _instruction = "Breathe Out";
        } else if (_instruction == "Breathe Out") {
          _instruction = "Breathe In";
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1), // Calming mint green background
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.teal),
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(height: 32),
            const Icon(Icons.self_improvement, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Fatigue Detected',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
            ).animate().fadeIn().slideY(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              child: Text(
                'You\'ve been studying for 3 hours straight. Let\'s take a 1-minute mindfulness break to reset your focus.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.teal),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(),
            
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The breathing circle
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal.withAlpha(50),
                      ),
                    ).animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    ).scaleXY(begin: 0.5, end: 1.5, duration: 4.seconds, curve: Curves.easeInOut),
                    
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal.withAlpha(100),
                      ),
                    ).animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    ).scaleXY(begin: 0.8, end: 1.2, duration: 4.seconds, curve: Curves.easeInOut),

                    Text(
                      _instruction,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ).animate(key: ValueKey(_instruction)).fadeIn(duration: 500.ms),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
                child: const Text('I\'m Ready to Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ).animate().scale(delay: 1.seconds),
            )
          ],
        ),
      ),
    );
  }
}
