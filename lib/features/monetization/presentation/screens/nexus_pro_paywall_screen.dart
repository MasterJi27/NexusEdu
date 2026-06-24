import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NexusProPaywallScreen extends StatelessWidget {
  const NexusProPaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(title: const Text('Go Pro', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 80).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.1),
            const SizedBox(height: 16),
            const Text('Nexus Pro', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const Text('Unlock your true potential.', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 48),
            _buildFeatureRow('Unlimited AI Tutor Chat'),
            _buildFeatureRow('Offline Vault Access'),
            _buildFeatureRow('Advanced Spaced Repetition Analytics'),
            _buildFeatureRow('Zero Ads. Pure Focus.'),
            const SizedBox(height: 48),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.amberAccent.withAlpha(50))),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Annual Plan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Save 40%', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ]),
                  Text('₹999 / yr', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ).animate().slideY(begin: 0.2).fade(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                fixedSize: const Size(300, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('UPGRADE NOW', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ).animate().scale(delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 40),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    ).animate().slideX(begin: -0.1).fade();
  }
}
