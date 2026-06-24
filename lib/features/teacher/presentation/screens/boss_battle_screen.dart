import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class BossBattleScreen extends StatefulWidget {
  const BossBattleScreen({super.key});

  @override
  State<BossBattleScreen> createState() => _BossBattleScreenState();
}

class _BossBattleScreenState extends State<BossBattleScreen> {
  double _bossHp = 1.0;

  void _attackBoss() {
    setState(() {
      _bossHp -= 0.1;
      if (_bossHp < 0) _bossHp = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Class Boss Battle ⚔️', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Column(
                children: [
                  Text('The Procrastinator Monster', style: TextStyle(color: Colors.redAccent.shade100, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    child: LinearProgressIndicator(
                      value: _bossHp,
                      minHeight: 20,
                      backgroundColor: Colors.white24,
                      color: _bossHp > 0.5 ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${(_bossHp * 10000).toInt()} / 10000 HP', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          
          Center(
            child: GestureDetector(
              onTap: _attackBoss,
              child: SizedBox(
                height: 300,
                // Using the pet animation as a mock "boss"
                child: Animate(
                  key: ValueKey(_bossHp),
                  child: Lottie.network('https://lottie.host/28f62c5a-d14d-456d-b8ba-b68482cc7c80/wRj2H9H8Yq.json'),
                ).shake(duration: 300.ms, hz: 4)
                 .tint(color: Colors.red, end: 0, duration: 300.ms),
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Question 4/10', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 16),
                  const Text('What year did the French Revolution start?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAnswerBtn('1776', false),
                      _buildAnswerBtn('1789', true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAnswerBtn('1812', false),
                      _buildAnswerBtn('1492', false),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnswerBtn(String text, bool correct) {
    return ElevatedButton(
      onPressed: () {
        if (correct) _attackBoss();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        fixedSize: const Size(150, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
