import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';


class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Educator Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.withAlpha(30),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCards(),
          const SizedBox(height: 24),
          const Text('Class Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _showingSections(),
              ),
            ).animate().fade().scale(),
          ),
          const SizedBox(height: 32),
          const Text('At-Risk Students', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 16),
          _buildStudentCard('Timmy Smith', 'Missed 3 assignments', Colors.redAccent),
          _buildStudentCard('Emma Davis', 'Failed recent quiz', Colors.orangeAccent),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment Broadcasted to 142 Students!')));
            },
            icon: const Icon(Icons.campaign),
            label: const Text('Broadcast Assignment to Class', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )
        ],
      ),
    );
  }

  List<PieChartSectionData> _showingSections() {
    return List.generate(4, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 20.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;
      const shadows = [Shadow(color: Colors.black, blurRadius: 2)];

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: Colors.green,
            value: 60,
            title: '60%\nA',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: shadows),
          );
        case 1:
          return PieChartSectionData(
            color: Colors.blue,
            value: 25,
            title: '25%\nB',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: shadows),
          );
        case 2:
          return PieChartSectionData(
            color: Colors.orange,
            value: 10,
            title: '10%\nC',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: shadows),
          );
        case 3:
          return PieChartSectionData(
            color: Colors.red,
            value: 5,
            title: '5%\nF',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, shadows: shadows),
          );
        default:
          throw Error();
      }
    });
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Students', '142', Icons.people, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Avg Quiz Score', '84%', Icons.analytics, Colors.green)),
      ],
    ).animate().slideY(begin: -0.2).fade();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [BoxShadow(color: color.withAlpha(10), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStudentCard(String name, String issue, Color color) {
    return Card(
      elevation: 4,
      shadowColor: color.withAlpha(100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: color.withAlpha(50), child: Icon(Icons.warning, color: color)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(issue),
        trailing: ElevatedButton(
          onPressed: () {}, 
          style: ElevatedButton.styleFrom(backgroundColor: color.withAlpha(30), foregroundColor: color, elevation: 0),
          child: const Text('Message')
        ),
      ),
    ).animate().slideX().fade();
  }
}
