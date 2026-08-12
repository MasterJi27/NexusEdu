import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

/// The bottom tab shell for the five primary destinations.
///
/// A floating pill bar: `surface` fill, hairline border, one `e1` shadow —
/// per DESIGN.md elevation levels, floating bars are the one place a shadow
/// earns its keep. The indicator, labels and icons come from
/// [NavigationBarThemeData] in `app_theme.dart`.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.child});

  final Widget child;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const _tabs = [
    '/dashboard',
    '/feed',
    '/tutor',
    '/notes',
    '/profile',
    '/classroom',
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((tab) => location.startsWith(tab));
    return index == -1 ? 0 : index;
  }

  void _onItemTapped(int index, BuildContext context) {
    HapticFeedback.lightImpact();
    context.go(_tabs[index]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final currentIndex = _selectedIndex(context);
    return Scaffold(
      body: Column(
        children: [
          const _OfflineBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.xs,
          AppSpace.md,
          AppSpace.sm,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(color: t.border),
            boxShadow: AppElevation.e1(t.shadow),
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            height: 64,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school),
                label: 'Learn',
              ),
              NavigationDestination(
                icon: Icon(Icons.swipe_outlined),
                selectedIcon: Icon(Icons.swipe),
                label: 'Shorts',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: 'Tutor',
              ),
              NavigationDestination(
                icon: Icon(Icons.sticky_note_2_outlined),
                selectedIcon: Icon(Icons.sticky_note_2),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.meeting_room_outlined),
                selectedIcon: Icon(Icons.meeting_room),
                label: 'Classroom',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim amber strip shown above the tab content whenever the backend is
/// unreachable. A single verdict from [ConnectivityService] drives this, the
/// AI gates and the reconnect-sync trigger.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        if (ConnectivityService.instance.online) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          color: t.statusLate.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 14, color: t.statusLate),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                  'Offline — AI features need internet. Saved work syncs when you reconnect.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: t.statusLate,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
