import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ParentSponsorshipScreen extends StatelessWidget {
  const ParentSponsorshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(title: const Text('Parental Sponsorships', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Active Bounties', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
          const SizedBox(height: 16),
          _buildBountyCard(
            context,
            'A in AP Calculus Exam',
            '\$50 Amazon Gift Card',
            Icons.card_giftcard,
            Colors.orange,
            0.8,
          ),
          _buildBountyCard(
            context,
            'Complete 7-Day Study Streak',
            '+2 Hours Screen Time',
            Icons.tv,
            Colors.purple,
            0.4,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Add New Sponsorship (Parent Only)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBountyCard(BuildContext context, String goal, String reward, IconData icon, Color color, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
              const SizedBox(width: 16),
              Expanded(child: Text(reward, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
            ],
          ),
          const SizedBox(height: 16),
          Text('Goal: $goal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, color: color, minHeight: 10, borderRadius: BorderRadius.circular(5)),
          const SizedBox(height: 8),
          Text('${(progress * 100).toInt()}% Complete', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    ).animate().slideX(begin: 0.2).fade();
  }
}
