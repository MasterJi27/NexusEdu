import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/org_brand_mark.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificationProgram {
  const CertificationProgram({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.roles,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;

  /// Roles that should see this program. 'student' shows it to students,
  /// 'teacher' to teachers (faculty), 'parent' to parents.
  final List<String> roles;

  bool get isTeacherProgram => roles.contains('teacher');
}

/// Google for Education certification programs. Role-filtered: teachers see
/// educator/faculty programs, students see student programs.
const kCertificationPrograms = <CertificationProgram>[
  CertificationProgram(
    id: 'educator-l1',
    title: 'Google Certified Educator Level 1',
    subtitle: 'Foundations of Google Workspace for Education',
    description:
        'Demonstrate your Google Workspace for Education product awareness '
        'and your understanding of how to effectively use key Google '
        'Workspace for Education features in the classroom.',
    icon: Icons.workspace_premium_outlined,
    roles: ['teacher'],
  ),
  CertificationProgram(
    id: 'educator-l2',
    title: 'Google Certified Educator Level 2',
    subtitle: 'Advanced Google Workspace for Education',
    description:
        'Demonstrate your pedagogical understanding of how to integrate '
        'Google Workspace for Education product features to support '
        'educational practices.',
    icon: Icons.workspace_premium,
    roles: ['teacher'],
  ),
  CertificationProgram(
    id: 'gemini-educator',
    title: 'Gemini Educator',
    subtitle: 'Google AI in the classroom',
    description:
        'Demonstrate your understanding of Gemini and responsible '
        'integration of Google AI for enhanced productivity, student '
        'success, and innovative learning experiences.',
    icon: Icons.auto_awesome,
    roles: ['teacher'],
  ),
  CertificationProgram(
    id: 'gemini-faculty',
    title: 'Gemini Faculty',
    subtitle: 'AI for research, teaching and curriculum',
    description:
        'Demonstrate your understanding of Gemini and responsible '
        'integration of Google AI for research productivity, supporting '
        'student engagement, and designing innovative curriculum.',
    icon: Icons.school_outlined,
    roles: ['teacher'],
  ),
  CertificationProgram(
    id: 'gemini-student',
    title: 'Gemini University Student',
    subtitle: 'AI for students',
    description:
        'Demonstrate your understanding of Gemini and responsible '
        'integration of Google AI for advanced research, academic rigor, '
        'and professional readiness.',
    icon: Icons.auto_awesome_outlined,
    roles: ['student'],
  ),
];

const _registerUrl = 'https://educertifications.google/register';

class CertificationsScreen extends StatelessWidget {
  const CertificationsScreen({super.key});

  List<CertificationProgram> _programsForRole() {
    final role = SecureApiService().role ?? 'student';
    return kCertificationPrograms
        .where((p) => p.roles.contains(role))
        .toList();
  }

  Future<void> _openRegister(BuildContext context) async {
    final uri = Uri.parse(_registerUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the registration page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final programs = _programsForRole();
    final orgName = SecureApiService().organizationName;
    final orgLogoUrl = SecureApiService().orgLogoUrl;
    final hasOrg = orgName != null && orgName.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: hasOrg
            ? OrgBrandMark(
                fallbackTitle: 'Certifications',
                name: orgName,
                logoUrl: orgLogoUrl,
              )
            : const Text('Certifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          if (hasOrg) ...[
            OrgBrandMark(
              fallbackTitle: 'Certifications',
              name: orgName,
              logoUrl: orgLogoUrl,
            ),
            const SizedBox(height: AppSpace.md),
          ],
          Text(
            'Professional certifications',
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Earn recognized credentials and showcase your skills. Register '
            'directly with Google for Education.',
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.lg),
          if (programs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Text(
                'No certification programs are available for your account '
                'type yet.',
                style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
              ),
            )
          else
            for (final program in programs) ...[
              _ProgramCard(
                program: program,
                onRegister: () => _openRegister(context),
              ),
              const SizedBox(height: AppSpace.md),
            ],
          const SizedBox(height: AppSpace.md),
          Text(
            'Official program details: ',
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.xs),
          InkWell(
            onTap: () => _openRegister(context),
            child: Text(
              _registerUrl,
              style: context.text.bodySmall?.copyWith(color: t.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onRegister});

  final CertificationProgram program;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final orgName = SecureApiService().organizationName?.trim();
    final hasOrg = orgName != null && orgName.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpace.md),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasOrg) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: AppRadius.brPill,
                border: Border.all(color: t.primaryTintBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined, size: 12, color: t.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      orgName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: t.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: BorderRadius.circular(AppSpace.sm),
                ),
                child: Icon(program.icon, color: t.primary, size: 22),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  program.title,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            program.subtitle,
            style: context.text.bodySmall?.copyWith(color: t.primary),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            program.description,
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Register'),
            ),
          ),
        ],
      ),
    );
  }
}