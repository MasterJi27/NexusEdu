import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HardwareBundleScreen extends StatelessWidget {
  const HardwareBundleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('NexusEdu Hardware', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 280, height: 200, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade800, width: 4))),
                const Text('NexusEdu', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 48),
            const Text('The Ultimate Learning Bundle', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48.0),
              child: Text('Get a secure, distraction-free Samsung tablet pre-loaded with a 2-year Nexus Pro subscription.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.blueAccent.withAlpha(20), borderRadius: BorderRadius.circular(24)),
              child: const Text('₹14,999', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
            ).animate().slideY(begin: 0.2),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, fixedSize: const Size(250, 50)),
              child: const Text('Order Now'),
            )
          ],
        ),
      ),
    );
  }
}
