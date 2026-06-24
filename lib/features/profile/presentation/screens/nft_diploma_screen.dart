import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NftDiplomaScreen extends StatelessWidget {
  const NftDiplomaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('Verified Credentials', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 320,
                  height: 420,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.amberAccent.withAlpha(100), blurRadius: 40, spreadRadius: 10)],
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds, color: Colors.white54),
                
                Container(
                  width: 310,
                  height: 410,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 80),
                      const SizedBox(height: 24),
                      const Text('Certificate of Mastery', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('Advanced Python Data Structures', style: TextStyle(color: Colors.amberAccent, fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      const Text('Issued to Alex', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: const Text('TxHash: 0x8fB3...9aA2\nVerified on Ethereum', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'), textAlign: TextAlign.center),
                      )
                    ],
                  ),
                )
              ],
            ).animate().slideY(begin: 0.1).scale(),
            
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_link),
              label: const Text('Add to LinkedIn'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0077B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            ).animate().fade(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
