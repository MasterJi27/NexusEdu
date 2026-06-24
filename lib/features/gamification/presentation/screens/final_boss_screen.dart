import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FinalBossScreen extends StatefulWidget {
  const FinalBossScreen({super.key});

  @override
  State<FinalBossScreen> createState() => _FinalBossScreenState();
}

class _FinalBossScreenState extends State<FinalBossScreen> {
  double bossHp = 1.0;
  int studentHearts = 3;

  void _attackBoss() {
    setState(() {
      bossHp -= 0.34;
      if (bossHp < 0) bossHp = 0;
    });
  }

  void _wrongAnswer() {
    setState(() {
      if (studentHearts > 0) studentHearts--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('FINAL EXAM: The AI Overlord', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.redAccent)),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Boss HP Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Text('AI Overlord', style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 5)),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(height: 20, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
                      AnimatedContainer(
                        duration: 300.ms,
                        height: 20,
                        width: MediaQuery.of(context).size.width * 0.85 * bossHp,
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.redAccent.withAlpha(100), blurRadius: 10)]),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().slideY(begin: -0.2),
            const Spacer(),
            
            // The Boss Animation (Mocked with an Icon for now)
            bossHp > 0 
                ? const Icon(Icons.smart_toy, color: Colors.redAccent, size: 150).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.1).shake(hz: 2, duration: 2.seconds)
                : const Icon(Icons.workspace_premium, color: Colors.amber, size: 150).animate().scale().shimmer(duration: 2.seconds),
            
            const Spacer(),

            // Student Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Alex Learner', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(3, (index) => Icon(index < studentHearts ? Icons.favorite : Icons.favorite_border, color: Colors.greenAccent, size: 30)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Question Area
            if (bossHp > 0 && studentHearts > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.redAccent.withAlpha(50), width: 2)),
                child: Column(
                  children: [
                    const Text('What is the worst-case time complexity of QuickSort?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    _buildAnswerBtn('O(n log n)', false),
                    _buildAnswerBtn('O(n^2)', true),
                    _buildAnswerBtn('O(1)', false),
                  ],
                ),
              ).animate().slideY(begin: 0.2)
            else if (bossHp <= 0)
              _buildVictory()
            else
              _buildDefeat(),
              
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerBtn(String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (isCorrect) {
              _attackBoss();
            } else {
              _wrongAnswer();
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text(text, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildVictory() {
    return Column(
      children: [
        const Text('BOSS DEFEATED!', style: TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)).animate().scale().shake(),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), child: const Text('Claim Grandmaster NFT'))
      ],
    );
  }

  Widget _buildDefeat() {
    return Column(
      children: [
        const Text('YOU DIED', style: TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 5)).animate().scale().shake(),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white), child: const Text('Revive & Retry'))
      ],
    );
  }
}
