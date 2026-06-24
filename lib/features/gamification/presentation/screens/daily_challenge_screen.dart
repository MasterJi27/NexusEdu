import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Daily Global Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Puzzle #492', style: TextStyle(color: Colors.grey, fontSize: 18, letterSpacing: 2)),
            const SizedBox(height: 16),
            const Text('Who was the 16th US President?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLetterBox('L', Colors.green),
                _buildLetterBox('I', Colors.green),
                _buildLetterBox('N', Colors.green),
                _buildLetterBox('C', Colors.green),
                _buildLetterBox('O', Colors.green),
                _buildLetterBox('L', Colors.green),
                _buildLetterBox('N', Colors.green),
              ],
            ).animate().shake(hz: 4, duration: 400.ms),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  const Text('Spectacular!', style: TextStyle(color: Colors.green, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('You maintained your 14-day streak.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    label: const Text('Share Result'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  )
                ],
              ),
            ).animate().scale(delay: 500.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterBox(String letter, Color color) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }
}
