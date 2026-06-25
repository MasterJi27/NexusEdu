import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.child});

  final Widget child;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
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

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF171A21),
        elevation: 0,
        height: 68,
        indicatorColor: const Color(0xFF7C5CFF).withAlpha(55),
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) => _onItemTapped(idx, context),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: 22),
            selectedIcon: Icon(Icons.dashboard, size: 22),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.swipe_outlined, size: 22),
            selectedIcon: Icon(Icons.swipe, size: 22),
            label: 'Shorts',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined, size: 22),
            selectedIcon: Icon(Icons.smart_toy, size: 22),
            label: 'Tutor',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined, size: 22),
            selectedIcon: Icon(Icons.sticky_note_2, size: 22),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 22),
            selectedIcon: Icon(Icons.person, size: 22),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
