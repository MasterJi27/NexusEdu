import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            'Your data is stored locally on your device using SharedPreferences. No data is uploaded to external servers unless explicitly requested (e.g., Gemini AI API calls). You retain full control over your data at all times.',
          ),
          _buildSection(
            'Third Party Services',
            'NexusEdu integrates with the following third-party services:\n\n'
                '• Google Gemini AI API — for AI-powered content generation and tutoring\n'
                '• speech_to_text — for voice-based learning features\n'
                '• Google Play Services — for installation and updates',
          ),
          _buildSection(
            'Data Security',
            'All data is processed locally. API calls to Gemini are encrypted using industry-standard protocols. We implement security measures to protect your information from unauthorized access.',
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
          const SizedBox(height: 8),
          const Text(
            'Last updated: June 2026',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(_privacyUrl)),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View Full Policy Online'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (widget.isFirstTime) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _acceptPolicy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
