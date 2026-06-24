import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DataMonetizationDashboardScreen extends StatelessWidget {
  const DataMonetizationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('B2B Publisher Insights', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Learning Gap Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const Text('Selling anonymized failure data to Pearson Education.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          _buildInsightCard('Calculus Chapter 4', '68% of 100k students failed the integration quiz. Content is too complex.', Colors.redAccent),
          _buildInsightCard('Physics Vectors', 'Requires 3.4x more time than average to complete.', Colors.orangeAccent),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(24)),
            child: const Column(
              children: [
                Icon(Icons.sell, color: Colors.white, size: 40),
                SizedBox(height: 16),
                Text('Sell Data Batch', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Est. Value: \$45,000', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ).animate().scale()
        ],
      ),
    );
  }

  Widget _buildInsightCard(String topic, String insight, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withAlpha(50)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(insight, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    ).animate().slideX(begin: -0.1);
  }
}
