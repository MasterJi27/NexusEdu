import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EasterEggScreen extends StatefulWidget {
  const EasterEggScreen({super.key});

  @override
  State<EasterEggScreen> createState() => _EasterEggScreenState();
}

class _EasterEggScreenState extends State<EasterEggScreen> {
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CRT Monitor Effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: NetworkImage('https://www.transparenttextures.com/patterns/stardust.png'),
                  repeat: ImageRepeat.repeat,
                ),
                gradient: RadialGradient(
                  colors: [Colors.green.withAlpha(50), Colors.black],
                  radius: 1.5,
                ),
              ),
            ),
          ),
          
          // Scanline animation
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                height: 4,
                color: Colors.greenAccent.withAlpha(20),
              ).animate(onPlay: (c) => c.repeat()).moveY(begin: -800, end: 800, duration: 4.seconds),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SYSTEM OVERRIDE',
                  style: TextStyle(color: Colors.redAccent, fontSize: 32, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 200.ms),
                const SizedBox(height: 32),
                const Text(
                  'DEFEND THE NEXUS',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 48, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 64),
                
                // Mock Asteroids Game UI
                SizedBox(
                  height: 300,
                  width: 300,
                  child: Stack(
                    children: [
                      Center(child: const Icon(Icons.rocket_launch, color: Colors.greenAccent, size: 48).animate(onPlay: (c) => c.repeat(reverse: true)).shake(hz: 4, duration: 200.ms)),
                      
                      // Falling Math Equation
                      Align(
                        alignment: const Alignment(-0.8, -1.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _score += 100),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(border: Border.all(color: Colors.redAccent)),
                            child: const Text('2x + 4 = 10', style: TextStyle(color: Colors.redAccent, fontFamily: 'monospace')),
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat()).moveY(begin: 0, end: 300, duration: 3.seconds),
                      
                      // Falling Math Equation
                      Align(
                        alignment: const Alignment(0.6, -1.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _score += 150),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(border: Border.all(color: Colors.redAccent)),
                            child: const Text('x^2 = 16', style: TextStyle(color: Colors.redAccent, fontFamily: 'monospace')),
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat()).moveY(begin: -50, end: 300, duration: 2.5.seconds),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Text('SCORE: $_score', style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                const SizedBox(height: 48),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('RETURN TO NORMALCY', style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
