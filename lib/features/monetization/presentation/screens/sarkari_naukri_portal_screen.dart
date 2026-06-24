import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SarkariNaukriPortalScreen extends StatelessWidget {
  const SarkariNaukriPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Sarkari Naukri Alerts', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.orange, Colors.redAccent]), borderRadius: BorderRadius.circular(24)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UPSC Civil Services 2026', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Notification Released. 1056 Vacancies.', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ).animate().slideY(begin: -0.2),
          const SizedBox(height: 24),
          const Text('1-Click Apply (Nexus Auto-Fill)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildJobCard('SSC CGL 2026', 'Staff Selection Commission', '₹49 to Auto-Apply', Colors.blue),
          _buildJobCard('IBPS PO Prelims', 'Banking Personnel', '₹49 to Auto-Apply', Colors.green),
        ],
      ),
    );
  }

  Widget _buildJobCard(String title, String dept, String price, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(dept, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                child: const Text('Auto-Apply'),
              )
            ],
          )
        ],
      ),
    ).animate().scale();
  }
}
