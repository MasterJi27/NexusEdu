import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FeatureGalleryScreen extends StatelessWidget {
  const FeatureGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A), // Sleek pitch black
        appBar: AppBar(
          title: const Text('Nexus Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E1E1E),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.deepPurpleAccent,
            labelColor: Colors.deepPurpleAccent,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.school, size: 20), text: 'Students'),
              Tab(icon: Icon(Icons.business, size: 20), text: 'Enterprise'),
              Tab(icon: Icon(Icons.attach_money, size: 20), text: 'Revenue'),
              Tab(icon: Icon(Icons.rocket, size: 20), text: 'Future'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStudentTab(),
            _buildStakeholderTab(),
            _buildMonetizationTab(),
            _buildFutureTechTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader('Core Learning'),
        _buildFeatureCard(Icons.school, 'E-Learning Curriculum', 'Class -> Subject -> Topic -> Learning path.', Colors.deepOrangeAccent, '/elearning-class'),
        _buildFeatureCard(Icons.dashboard, 'Vidyarthi Hub', 'Live Classes, Doubts, & External Courses.', Colors.amber, '/student-hub'),
        _buildFeatureCard(Icons.psychology, 'Socratic Math Solver', 'AI guiding you step-by-step.', Colors.blueAccent, '/socratic-solver'),
        _buildFeatureCard(Icons.local_fire_department, 'AI Essay Roaster', 'Harsh but constructive essay grading.', Colors.orange, '/essay-roaster'),
        _buildFeatureCard(Icons.show_chart, 'Forgetting Curve', 'Spaced-repetition memory analytics.', Colors.redAccent, '/forgetting-curve'),
      ],
    );
  }

  Widget _buildStakeholderTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader('School & Enterprise'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Text('Enterprise dashboard is currently being customized for our pilot partners.', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildMonetizationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader('India-Core Business Models'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Text('Monetization channels are disabled in this demo environment.', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildFutureTechTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader('Immersion'),
        _buildFeatureCard(Icons.code, 'Code Sandbox', 'In-app Python IDE.', Colors.green, '/code-sandbox'),
        
        const SizedBox(height: 24),
        _buildCategoryHeader('Advanced Computing'),
        _buildFeatureCard(Icons.accessibility_new, 'Accessibility Hub', 'ADHD & Dyslexia Inclusive Modes.', Colors.blueAccent, '/accessibility-hub'),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 8),
      child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle, Color color, String route) {
    return Builder(
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: ListTile(
            onTap: () {
              context.push(route);
            },
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ),
        ).animate().fadeIn().slideX(begin: 0.1);
      }
    );
  }
}
