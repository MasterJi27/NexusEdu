import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CeoFinancialDashboardScreen extends StatelessWidget {
  const CeoFinancialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text('Founder Unit Economics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCard('MRR', '₹1.2M', '+15%', Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('CAC', '₹240', '-5%', Colors.redAccent)),
            ],
          ).animate().slideY(begin: 0.1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard('LTV', '₹4,500', '+8%', Colors.blueAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Churn Rate', '2.1%', '-1%', Colors.orangeAccent)),
            ],
          ).animate().slideY(begin: 0.1, delay: 100.ms),
          const SizedBox(height: 32),
          const Text('Revenue Trajectory', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24)),
            child: const Center(child: Icon(Icons.show_chart, size: 100, color: Colors.greenAccent)),
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blueAccent.withAlpha(20), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueAccent.withAlpha(50))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LTV:CAC Ratio', style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 8),
                Text('18.75x', style: TextStyle(color: Colors.blueAccent, fontSize: 36, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Exceptional unit economics. Highly scalable.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ).animate().scale(delay: 300.ms)
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String trend, Color trendColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendColor == Colors.greenAccent ? Icons.arrow_upward : Icons.arrow_downward, color: trendColor, size: 16),
              const SizedBox(width: 4),
              Text(trend, style: TextStyle(color: trendColor, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
