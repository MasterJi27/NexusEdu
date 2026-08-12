import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';
import 'package:nexus_edu/shared/widgets/role_selector.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.initialRole});

  /// Role carried over from the login screen ("I am a…" selector), if any.
  final String? initialRole;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = AuthState.instance.selectedRole ?? 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null) {
      _selectedRole = widget.initialRole!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fill in every field to continue.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await AuthState.instance.setSelectedRole(_selectedRole);
    final result = await AuthState.instance.signup(name, email, password);
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

    if (mounted) context.go(await AuthState.instance.resolveHomeAfterSignup());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Sign up',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                  'Create an account — study tools, notes and progress in one place.',
                  style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.xl),
                Text('I am a…', style: context.text.labelMedium),
                const SizedBox(height: AppSpace.xs),
                RoleSelector(
                  value: _selectedRole,
                  onChanged: (role) => setState(() => _selectedRole = role),
                ),
                const SizedBox(height: AppSpace.lg),
                NexusTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.person_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.sm),
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
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  isPassword: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signup(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Text(
                      _obscurePassword ? 'Show passwords' : 'Hide passwords',
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  NexusBanner(message: _error!, kind: NexusBannerKind.error),
                ],
                const SizedBox(height: AppSpace.md),
                NexusButton(
                  label: 'Sign up',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _signup,
                  fullWidth: true,
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: context.text.bodySmall,
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        'Log in',
                        style: context.text.bodySmall?.copyWith(
                          color: t.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
