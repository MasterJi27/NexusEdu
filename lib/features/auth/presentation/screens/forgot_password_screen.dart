import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email to continue.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await SecureApiService().forgotPassword(email);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['error'] != null) {
      setState(() => _error = result['error'].toString());
      return;
    }

    final devToken = result['devToken']?.toString();
    if (devToken != null && devToken.isNotEmpty) {
      // Dev mode: the backend can't email, so show the token so the flow can
      // be completed end-to-end. Production hides this entirely.
      await _showDevToken(devToken);
    } else {
      _showConfirmation();
    }
  }

  Future<void> _showDevToken(String token) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset link generated (dev mode)'),
        content: Text(
          'No email service is configured, so here is your reset token.\n\n$token\n\n'
          'Use it on the next screen to set a new password.',
          style: dialogContext.text.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              dialogContext.pop();
              context.go('/reset-password?token=$token');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _error = null);
  }

  void _showConfirmation() {
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'If an account exists, a reset link has been sent to your email.',
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Forgot password',
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
                  'We\'ll email you a link to reset your password.',
                  style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.xl),
                NexusTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _sendResetLink(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  NexusBanner(message: _error!, kind: NexusBannerKind.error),
                ],
                const SizedBox(height: AppSpace.md),
                NexusButton(
                  label: 'Send reset link',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _sendResetLink,
                  fullWidth: true,
                ),
                const SizedBox(height: AppSpace.sm),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/reset-password'),
                    child: const Text(
                      'Already have a reset link? Enter it here',
                    ),
                  ),
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
