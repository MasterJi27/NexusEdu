import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Persona chosen on the welcome screen. Read-only here by design: the sign
  /// in form must not be able to change an account's role, so this only labels
  /// the guest button and carries the choice through to signup.
  late final String _selectedRole =
      AuthState.instance.selectedRole ?? 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  String get _roleLabel => switch (_selectedRole) {
    'parent' => 'Parent',
    'teacher' => 'Teacher',
    _ => 'Student',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Deliberately no setSelectedRole here: signing in must never change the
    // account's role. resolveHomeAfterLogin adopts whatever the server says.
    final result = await AuthState.instance.login(email, password);
    if (!mounted) return;

    switch (result) {
      case Failure():
        setState(() {
          _isLoading = false;
          _error = result.message;
        });
        return;
      case Success():
        break;
    }

    if (mounted) context.go(await AuthState.instance.resolveHomeAfterLogin());
  }

  /// Guests have no account, so the persona picked on the welcome screen is
  /// purely a local preview of that dashboard — nothing is sent to the server.
  Future<void> _continueAsGuest() async {
    await AuthState.instance.markGuest();
    if (mounted) context.go(AuthState.instance.roleHome);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Log in',
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpace.pageH,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.xxl),
                Text(
                  'Nexus Edu',
                  style: context.text.displaySmall?.copyWith(color: t.ink),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  'Welcome back. Sign in, or keep browsing as a guest.',
                  style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.xl),
                NexusTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outlined,
                  isPassword: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Text(
                        _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  NexusBanner(message: _error!, kind: NexusBannerKind.error),
                ],
                const SizedBox(height: AppSpace.md),
                NexusButton(
                  label: 'Log in',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _login,
                  fullWidth: true,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusButton(
                  label: 'Continue as $_roleLabel guest',
                  icon: Icons.explore_outlined,
                  variant: NexusButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: _isLoading ? null : _continueAsGuest,
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: context.text.bodySmall,
                    ),
                    GestureDetector(
                      onTap: () => context.push('/signup?role=$_selectedRole'),
                      child: Text(
                        'Sign up',
                        style: context.text.bodySmall?.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
