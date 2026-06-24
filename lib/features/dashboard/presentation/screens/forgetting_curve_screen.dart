import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForgettingCurveScreen extends StatelessWidget {
  const ForgettingCurveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Analytics', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('The Ebbinghaus Forgetting Curve', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('NexusEdu tracks when your memory decays to prompt reviews exactly when you need them.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 32),
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) => Text('Day ${v.toInt()}'))),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [FlSpot(0, 100), FlSpot(1, 80), FlSpot(2, 60), FlSpot(3, 40), FlSpot(4, 30), FlSpot(5, 20)],
                      isCurved: true,
                      color: Colors.redAccent,
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: const [FlSpot(1, 100), FlSpot(2, 90), FlSpot(3, 75), FlSpot(4, 60), FlSpot(5, 50)],
                      isCurved: true,
                      color: Colors.orangeAccent,
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: const [FlSpot(3, 100), FlSpot(4, 95), FlSpot(5, 85)],
                      isCurved: true,
                      color: Colors.greenAccent,
                      barWidth: 4,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ).animate().fade(duration: 800.ms).scale(begin: const Offset(1, 0.5)),
            ),
            const SizedBox(height: 32),
            const Text('Action Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 16),
            _buildAlertCard(context, 'Photosynthesis', 'Memory decayed to 40%. Review now.', Colors.redAccent),
            _buildAlertCard(context, 'French Conjugations', 'Memory decayed to 60%. Review tomorrow.', Colors.orangeAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, String title, String subtitle, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: color.withAlpha(30), foregroundColor: color, elevation: 0),
          child: const Text('Review'),
        ),
      ),
    ).animate().slideX().fade();
  }
}
