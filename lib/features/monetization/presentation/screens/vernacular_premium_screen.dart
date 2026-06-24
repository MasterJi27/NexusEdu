import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VernacularPremiumScreen extends StatelessWidget {
  const VernacularPremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Language Settings', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.translate, size: 80, color: Colors.blueAccent).animate().shake(hz: 3, duration: 1.seconds),
              const SizedBox(height: 24),
              const Text('Learn in your mother tongue.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text('Get flawless AI translation for all video lectures and notes in Tamil, Telugu, Hindi, Marathi, and Bengali.', style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.blueAccent.withAlpha(20), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueAccent.withAlpha(50))),
                child: const Column(
                  children: [
                    Text('Vernacular Pass', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    SizedBox(height: 8),
                    Text('₹99 / month', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                  ],
                ),
              ).animate().slideY(begin: 0.2),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, fixedSize: const Size(double.infinity, 60)),
                child: const Text('Unlock Local Languages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
