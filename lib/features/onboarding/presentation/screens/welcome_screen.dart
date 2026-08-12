import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';

class _Persona {
  const _Persona({
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String role;
  final String title;
  final String description;
  final IconData icon;
}

const List<_Persona> _personas = [
  _Persona(
    role: 'student',
    title: 'Student',
    description: 'Study tools, quizzes, shorts and mock tests.',
    icon: Icons.school_outlined,
  ),
  _Persona(
    role: 'parent',
    title: 'Parent',
    description: 'See your child\u2019s attendance and progress.',
    icon: Icons.family_restroom_outlined,
  ),
  _Persona(
    role: 'teacher',
    title: 'Teacher',
    description: 'Publish notes and take attendance by section.',
    icon: Icons.co_present_outlined,
  ),
];

/// Pre-auth welcome. One question, three answers: "Who's using Nexus Edu?"
/// The chosen persona drives the role of the guest session and the login
/// screen behind the Continue button. Follows the active theme instead of
/// forcing a dark screen, so the theme switch in Settings stays honest.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _selectedRole = 'student';

  Future<void> _continue() async {
    await AuthState.instance.setSelectedRole(_selectedRole);
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _skip() async {
    await AuthState.instance.setSelectedRole('student');
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: AppSpace.pageH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Nexus Edu',
                      style: context.text.displaySmall?.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'The study app that also keeps the classroom record.',
                      style: context.text.bodyMedium?.copyWith(
                        color: t.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      'Who\u2019s using Nexus Edu?',
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'Pick your role. You can continue as a guest right away.',
                      style: context.text.bodySmall?.copyWith(
                        color: t.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    for (final persona in _personas) ...[
                      _buildPersonaCard(persona),
                      const SizedBox(height: AppSpace.sm),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    FilledButton(
                      onPressed: _continue,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSpace.minTapTarget,
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Skip for now'),
                    ),
                    const SizedBox(height: AppSpace.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonaCard(_Persona persona) {
    final t = context.tokens;
    final selected = _selectedRole == persona.role;
    return Material(
      color: selected ? t.primaryTint : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: selected ? t.primary : t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedRole = persona.role),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? t.primary : t.surfaceAlt,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  persona.icon,
                  size: 22,
                  color: selected ? t.onPrimary : t.inkMuted,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.title,
                      style: context.text.titleMedium?.copyWith(
                        color: selected ? t.primary : t.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      persona.description,
                      style: context.text.bodySmall?.copyWith(
                        color: t.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: t.primary, size: 22)
              else
                Icon(Icons.circle_outlined, color: t.inkFaint, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
