import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class IotPostureScreen extends StatelessWidget {
  const IotPostureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('IoT Biometrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.redAccent)),
              child: Row(
                children: [
                  const Icon(Icons.camera_front, color: Colors.redAccent, size: 40).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 1),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Posture Alert!', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Camera detects slouching. Please sit up straight.', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().slideY(begin: -0.2),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueAccent)),
              child: Row(
                children: [
                  const Icon(Icons.watch, color: Colors.blueAccent, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stress AI Synced', style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Heart rate is stable at 72 BPM.', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().slideY(begin: 0.2),
            const Spacer(),
            const Icon(Icons.fingerprint, color: Colors.white12, size: 100),
            const SizedBox(height: 16),
            const Text('Hardware Active', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
