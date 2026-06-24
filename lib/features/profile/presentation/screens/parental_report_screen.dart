import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

class ParentalReportScreen extends StatefulWidget {
  const ParentalReportScreen({super.key});

  @override
  State<ParentalReportScreen> createState() => _ParentalReportScreenState();
}

class _ParentalReportScreenState extends State<ParentalReportScreen> {
  bool _isGenerating = false;
  bool _isGenerated = false;

  void _generateReport() {
    setState(() => _isGenerating = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _isGenerated = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parental Report Generator')),
      body: _isGenerated ? _buildReportPreview() : _buildGenerateView(),
    );
  }

  Widget _buildGenerateView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 100, color: Colors.blueGrey.shade400).animate().fade().scale(),
            const SizedBox(height: 24),
            const Text(
              'Generate Weekly AI Insights',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a beautifully formatted PDF report detailing strengths, weaknesses, and focus areas to share with parents.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _isGenerating
                ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing performance data...'),
                    ],
                  ).animate().fadeIn()
                : ElevatedButton.icon(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Generate Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ).animate().scale(curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withAlpha(50)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text('WEEKLY PROGRESS REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2))),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student: Alex Learner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Grade: 10th', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Overall: A-', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Strengths & Weaknesses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0: return const Text('Math');
                                case 1: return const Text('Science');
                                case 2: return const Text('History');
                                case 3: return const Text('English');
                                default: return const Text('');
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 95, color: Colors.green, width: 16, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 88, color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 72, color: Colors.orange, width: 16, borderRadius: BorderRadius.circular(4))]),
                        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 85, color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(4))]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('AI Recommendations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('• Focus more on History flashcards this week.\n• Great job on Mathematics! Keep up the practice.\n• Try participating in 2 more Quiz Battles.', style: TextStyle(height: 1.5)),
              ],
            ),
          ).animate().slideY().fade(),
          
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing via WhatsApp...')));
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Email Draft...')));
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ).animate().slideY(begin: 0.5, delay: 300.ms).fade(),
        ],
      ),
    );
  }
}
