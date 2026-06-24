import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class B2BSchoolPortalScreen extends StatelessWidget {
  const B2BSchoolPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Enterprise Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Delhi Public School', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.indigo)),
          const Text('Active Licenses: 5,420', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildStatCard('Avg Study Time', '2.4 hrs/day', Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Engagement', '84%', Colors.green)),
            ],
          ),
          const SizedBox(height: 32),
          const Text('At-Risk Students (AI Flagged)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStudentRow('Rohan Sharma', 'Grade 10', 'Declining Math Scores', Colors.redAccent),
          _buildStudentRow('Priya Patel', 'Grade 12', 'High Burnout Detected', Colors.orangeAccent),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Purchase 500 More Licenses'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withAlpha(50))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    ).animate().scale();
  }

  Widget _buildStudentRow(String name, String grade, String alert, Color alertColor) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(grade),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: alertColor.withAlpha(30), borderRadius: BorderRadius.circular(12)),
        child: Text(alert, style: TextStyle(color: alertColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ).animate().slideX(begin: 0.1);
  }
}
