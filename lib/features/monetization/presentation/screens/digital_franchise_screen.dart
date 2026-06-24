import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DigitalFranchiseScreen extends StatelessWidget {
  const DigitalFranchiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nexus Partner Program', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurple]), borderRadius: BorderRadius.circular(24)),
              child: const Row(
                children: [
                  Icon(Icons.storefront, color: Colors.white, size: 50),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start your EdTech Business', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Become a digital reseller.', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().slideY(begin: -0.2),
            const SizedBox(height: 32),
            const Text('How it works:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(leading: CircleAvatar(child: Text('1')), title: Text('Buy a partner license for ₹5,000')),
            const ListTile(leading: CircleAvatar(child: Text('2')), title: Text('Get a unique affiliate tracking link')),
            const ListTile(leading: CircleAvatar(child: Text('3')), title: Text('Keep 40% of every subscription you sell')),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20)),
                child: const Text('Buy Partner License', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ).animate().scale()
          ],
        ),
      ),
    );
  }
}
