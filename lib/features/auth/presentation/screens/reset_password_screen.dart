import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.token = ''});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.token);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final token = _tokenController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (token.isEmpty) {
      setState(() => _error = 'Enter the reset token from your email.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await SecureApiService().resetPasswordResult(token, newPassword);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!handleResultError(context, result)) {
      setState(() => _error = (result as Failure).message);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated. Please sign in again.')),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Reset password',
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
                  'Enter the reset token and your new password.',
                  style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.xl),
                NexusTextField(
                  controller: _tokenController,
                  label: 'Reset token',
                  icon: Icons.vpn_key_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: _passwordController,
                  label: 'New password',
                  icon: Icons.lock_outlined,
                  isPassword: _obscurePassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: _confirmController,
                  label: 'Confirm new password',
                  icon: Icons.lock_outline,
                  isPassword: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _resetPassword(),
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
                  label: 'Reset password',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _resetPassword,
                  fullWidth: true,
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
