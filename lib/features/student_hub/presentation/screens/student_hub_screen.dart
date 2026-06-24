import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudentHubScreen extends StatelessWidget {
  const StudentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Vidyarthi Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.videocam), text: 'Live'),
              Tab(icon: Icon(Icons.forum), text: 'Doubts'),
              Tab(icon: Icon(Icons.link), text: 'Courses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLiveClasses(),
            _buildDoubtsForum(),
            _buildExternalCourses(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveClasses() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(Icons.live_tv, 'Physics Final Revision', 'Starting in 10 mins • Dr. Sharma', Colors.redAccent),
        _buildCard(Icons.play_arrow, 'Maths Calculus Part 2', 'Recorded 2 days ago', Colors.grey),
      ],
    ).animate().fade();
  }

  Widget _buildDoubtsForum() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(Icons.question_answer, 'Integration by parts shortcut?', '2 answers • Resolved', Colors.greenAccent),
        _buildCard(Icons.question_answer, 'Help with rotational mechanics', '0 answers • Unresolved', Colors.orangeAccent),
      ],
    ).animate().fade();
  }

  Widget _buildExternalCourses() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(Icons.school, 'NPTEL Computer Science', 'Free Certification from IIT Madras', Colors.blueAccent),
        _buildCard(Icons.language, 'MIT OpenCourseWare', 'Advanced Physics Series', Colors.purpleAccent),
      ],
    ).animate().fade();
  }

  Widget _buildCard(IconData icon, String title, String sub, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withAlpha(50))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
