import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:url_launcher/url_launcher.dart';

const String _privacyUrl = 'https://masterji27.github.io/NexusEdu-Privacy/';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool isFirstTime;

  const PrivacyPolicyScreen({super.key, this.isFirstTime = false});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  Future<void> _acceptPolicy() async {
    await AuthState.instance.markPrivacyAccepted();
    if (mounted) {
      // The router redirect will send the user wherever they need to go.
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        automaticallyImplyLeading: !widget.isFirstTime,
        leading: widget.isFirstTime
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
      ),
      bottomNavigationBar: widget.isFirstTime
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.xs,
                AppSpace.md,
                AppSpace.md,
              ),
              child: NexusButton(
                label: 'Accept and Continue',
                fullWidth: true,
                onPressed: _acceptPolicy,
              ),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          widget.isFirstTime ? 96 : AppSpace.md,
        ),
        children: [
          _buildSection(
            'Introduction',
            'NexusEdu is an AI-powered education app for Indian students. It provides personalized learning experiences, study materials, and tools to help students excel in their academic journey. This Privacy Policy explains how we handle your information.',
          ),
          _buildSection(
            'Information We Collect',
            'We collect the following information to provide and improve our services:\n\n'
                '• User name and email address\n'
                '• Study preferences and class/subject selections\n'
                '• Test results and quiz performance\n'
                '• Usage data and interaction with app features',
          ),
          _buildSection(
            'How We Use Information',
            'The information we collect is used to:\n\n'
                '• Personalize learning recommendations and content\n'
                '• Improve AI model responses and accuracy\n'
                '• Provide analytics on learning progress\n'
                '• Enhance app features based on usage patterns',
          ),
          _buildSection(
            'Data Storage',
            'Your data is stored locally on your device using SharedPreferences. No data is uploaded to external servers unless explicitly requested (e.g., AI tutoring API calls). You retain full control over your data at all times.',
          ),
          _buildSection(
            'Third Party Services',
            'NexusEdu integrates with the following third-party services:\n\n'
                '• Secure AI services — for AI-powered content generation and tutoring\n'
                '• speech_to_text — for voice-based learning features\n'
                '• Google Play Services — for installation and updates',
          ),
          _buildSection(
            'Data Security',
            'All data is processed locally. API calls to AI services are encrypted using industry-standard protocols. We implement security measures to protect your information from unauthorized access.',
          ),
          _buildSection(
            "Children's Privacy",
            "The app is designed for students of all ages. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal data, please contact us so we can remove it.",
          ),
          _buildSection(
            'User Rights',
            'You have full control over your data. You can clear all app data by navigating to device Settings > Apps > NexusEdu > Storage > Clear Data. This will reset all locally stored information.',
          ),
          _buildSection(
            'Changes to Policy',
            'We may update this Privacy Policy from time to time. Any changes will be reflected within the app. We encourage you to review this policy periodically. Continued use of the app after changes constitutes acceptance of the updated policy.',
          ),
          _buildSection(
            'Contact',
            'If you have any questions or concerns regarding this Privacy Policy, please reach out:\n\nDeveloper: Ragha\nEmail: Raghavkathuria@devflow.me',
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Last updated: June 2026',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: t.inkFaint),
          ),
          const SizedBox(height: AppSpace.md),
          NexusButton(
            label: 'View Full Policy Online',
            icon: Icons.open_in_new,
            variant: NexusButtonVariant.secondary,
            fullWidth: true,
            onPressed: () => launchUrl(Uri.parse(_privacyUrl)),
          ),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    final t = context.tokens;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            body,
            style: context.text.bodyMedium?.copyWith(
              height: 1.5,
              color: t.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
