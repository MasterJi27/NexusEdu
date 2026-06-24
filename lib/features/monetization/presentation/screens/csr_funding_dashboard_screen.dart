import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CsrFundingDashboardScreen extends StatelessWidget {
  const CsrFundingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('Tata Group CSR Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Impact Dashboard', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Students Sponsored', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('10,000', style: TextStyle(color: Colors.greenAccent, fontSize: 48, fontWeight: FontWeight.w900)),
                const SizedBox(height: 24),
                LinearProgressIndicator(value: 0.8, backgroundColor: Colors.white12, color: Colors.greenAccent, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                const Text('80% average engagement rate', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ).animate().scale(),
          const SizedBox(height: 32),
          const Text('Top Performing Regions', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildRegionStat('Maharashtra (Rural)', '+15% avg test score'),
          _buildRegionStat('Odisha', '+12% avg test score'),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Sponsor 5,000 More Students'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildRegionStat(String region, String stat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(region, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(stat, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }
}
