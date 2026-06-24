import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TutorMarketplaceScreen extends StatelessWidget {
  const TutorMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Doubt Resolution', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.blueAccent.withAlpha(20),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                SizedBox(width: 16),
                Expanded(child: Text('AI cannot solve this complex integration. Do you want to connect to a human expert?', style: TextStyle(fontSize: 16))),
              ],
            ),
          ).animate().slideY(begin: -0.2),
          const SizedBox(height: 24),
          const Text('Available Experts Online', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTutorCard('Vikram Singh', 'IIT Delhi - 4th Year', '₹20 / min', 4.9),
                _buildTutorCard('Ananya D.', 'BITS Pilani', '₹15 / min', 4.7),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTutorCard(String name, String creds, String rate, double rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundImage: NetworkImage('https://i.pravatar.cc/100')),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                Text(creds, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' $rating', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                )
              ],
            ),
          ),
          Column(
            children: [
              Text(rate, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: const Text('Call Now'),
              )
            ],
          )
        ],
      ),
    ).animate().scale(delay: 200.ms);
  }
}
