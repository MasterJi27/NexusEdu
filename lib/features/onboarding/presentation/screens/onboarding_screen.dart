import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withAlpha(50),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 10.seconds),
          
          PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: [
              _buildPage(
                'AI Custom Roadmaps',
                'Instantly generate learning paths for any topic, formatted as interactive skill trees.',
                Icons.account_tree,
                Colors.blueAccent,
              ),
              _buildPage(
                'Socratic Voice Tutor',
                'Don\'t just read answers. Speak to your AI Tutor and let it guide your critical thinking.',
                Icons.record_voice_over,
                Colors.redAccent,
              ),
              _buildPage(
                '3D Augmented Reality',
                'Explore biology, physics, and engineering through interactive 3D models.',
                Icons.view_in_ar,
                Colors.tealAccent,
              ),
              _buildAuthPage(),
            ],
          ),
          
          if (_currentPage < 3)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.white : Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            
          if (_currentPage < 3)
            Positioned(
              bottom: 36,
              right: 24,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                onPressed: () => _pageController.nextPage(duration: 300.ms, curve: Curves.easeIn),
                child: const Icon(Icons.arrow_forward_ios),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPage(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: color).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 48),
          Text(
            title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.5, end: 0).fade(),
          const SizedBox(height: 24),
          Text(
            desc,
            style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
            textAlign: TextAlign.center,
          ).animate().slideY(begin: 0.5, end: 0, delay: 200.ms).fade(),
        ],
      ),
    );
  }

  Widget _buildAuthPage() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hub, size: 100, color: Colors.deepPurpleAccent).animate().scale(),
          const SizedBox(height: 32),
          const Text('Welcome to NexusEdu', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('Who are you?', style: TextStyle(fontSize: 18, color: Colors.white54)),
          const SizedBox(height: 32),
          _buildRoleCard(
            title: 'Student',
            subtitle: 'Personalized learning & AI tutor',
            icon: Icons.school,
            gradientColors: [Colors.blueAccent, Colors.blue.shade900],
            route: '/dashboard',
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            title: 'Parent',
            subtitle: 'Track your child\'s progress',
            icon: Icons.family_restroom,
            gradientColors: [Colors.tealAccent, Colors.teal.shade900],
            route: '/parent-dashboard',
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            title: 'Teacher',
            subtitle: 'Manage classes & assignments',
            icon: Icons.co_present,
            gradientColors: [Colors.orangeAccent, Colors.deepOrange.shade900],
            route: '/teacher-dashboard',
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text(
              'Continue as Guest',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.15);
  }
}

