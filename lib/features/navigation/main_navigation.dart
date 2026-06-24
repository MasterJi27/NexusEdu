import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(
                      context,
                    ).navigationBarTheme.backgroundColor?.withAlpha(120) ??
                    Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withAlpha(30),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                height: 65,
                indicatorColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                selectedIndex: currentIndex,
                onDestinationSelected: (idx) => _onItemTapped(idx, context),
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
            ),
          ),
        ),
      ),
    );
  }
}
