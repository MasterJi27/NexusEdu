import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/voice_navigation_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final Widget child;
  const MainNavigationScreen({super.key, required this.child});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/feed')) return 1;
    if (location.startsWith('/tutor')) return 2;
    if (location.startsWith('/notes')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    HapticFeedback.lightImpact();
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/feed');
        break;
      case 2:
        context.go('/tutor');
        break;
      case 3:
        context.go('/notes');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  void _handleVoiceCommand() async {
    final svc = VoiceNavigationService.instance;
    final text = await svc.startListening();
    if (!mounted) return;

    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not hear you. Try again.')),
      );
      return;
    }

    final route = svc.matchCommand(text);
    if (route != null) {
      context.go(route);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigating to $route')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Heard: "$text" — no matching command')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          Positioned(
            right: 20,
            bottom: 90,
            child: FloatingActionButton.small(
              onPressed: _handleVoiceCommand,
              backgroundColor: Colors.deepPurpleAccent.withAlpha(200),
              heroTag: 'voice_nav',
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 8,
        height: 65,
        indicatorColor: const Color(0xFF6200EA).withAlpha(80),
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) => _onItemTapped(idx, context),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Colors.white60, size: 22),
            selectedIcon: Icon(Icons.dashboard, color: Colors.white, size: 22),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.swipe_outlined, color: Colors.white60, size: 22),
            selectedIcon: Icon(Icons.swipe, color: Colors.white, size: 22),
            label: 'Shorts',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined, color: Colors.white60, size: 22),
            selectedIcon: Icon(Icons.smart_toy, color: Colors.white, size: 22),
            label: 'Tutor',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined, color: Colors.white60, size: 22),
            selectedIcon: Icon(Icons.sticky_note_2, color: Colors.white, size: 22),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.white60, size: 22),
            selectedIcon: Icon(Icons.person, color: Colors.white, size: 22),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
