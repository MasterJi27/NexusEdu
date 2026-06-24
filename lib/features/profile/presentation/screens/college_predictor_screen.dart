import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CollegePredictorScreen extends StatelessWidget {
  const CollegePredictorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('College Predictor', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Target: Stanford University', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.deepPurple)),
          const SizedBox(height: 32),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(value: 0.28, strokeWidth: 16, backgroundColor: Colors.grey.shade200, color: Colors.deepPurple),
                ).animate().scale(curve: Curves.easeOutBack, duration: 1.seconds),
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('28%', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    Text('Probability', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const Text('How to improve your chances:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildActionItem('Boost AP Physics grade to A', '+12%', Colors.green),
          _buildActionItem('Complete 50 hours of volunteering', '+5%', Colors.green),
          _buildActionItem('Increase SAT Math score by 50 pts', '+15%', Colors.green),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String impact, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Text(impact, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    ).animate().slideX(begin: 0.1).fade();
  }
}
