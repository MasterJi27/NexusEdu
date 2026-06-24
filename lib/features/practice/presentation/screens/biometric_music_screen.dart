import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';

class BiometricMusicScreen extends StatelessWidget {
  const BiometricMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Biometric Focus Music', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Heart rate rings
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.redAccent.withAlpha(50), width: 2)),
                ).animate(onPlay: (c) => c.repeat()).scaleXY(begin: 1, end: 1.5, duration: 1.seconds).fade(end: 0),
                
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withAlpha(20)),
                ),
                
                const Icon(Icons.favorite, color: Colors.redAccent, size: 64).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.2, duration: 800.ms),
              ],
            ),
            const SizedBox(height: 48),
            const Text('84 BPM', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
            const Text('Stress Level: Elevated', style: TextStyle(color: Colors.redAccent, fontSize: 18)),
            const SizedBox(height: 48),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('AI Audio Engine', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Generating Lo-Fi at 60 BPM to lower heart rate...', style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      15, 
                      (index) => Container(
                        width: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(4)),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(begin: 0.2, end: Random().nextDouble() * 1.5, duration: Duration(milliseconds: 300 + Random().nextInt(500))),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
