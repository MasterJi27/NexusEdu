import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';

class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  String? _selectedClass;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedClass();
  }

  Future<void> _loadSelectedClass() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    if (!mounted) return;
    setState(() {
      _selectedClass = selectedClass;
      _isLoading = false;
    });
  }

  Future<void> _selectClass(String className) async {
    await LearnerProfileService.setSelectedClass(className);
    if (!mounted) return;
    setState(() => _selectedClass = className);
    context.push('/elearning-subject');
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Choose Class',
      actions: [
        TextButton.icon(
          onPressed: () async {
            await LearnerProfileService.setSelectedClass(null);
            if (!context.mounted) return;
            setState(() => _selectedClass = null);
            context.go('/feed');
          },
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('Guest'),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.lg,
                AppSpace.xl,
              ),
              children: [
                _buildInfoBanner(context),
                const SizedBox(height: AppSpace.lg),
                for (final className in LearningCatalog.classes)
                  _buildClassCard(context, className),
              ],
            ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(Icons.route, color: t.secondaryFill, size: 30),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              'Class selection locks Shorts, topics, and certificates to your syllabus.',
              style: context.text.bodySmall?.copyWith(
                color: t.inkMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, String className) {
    final t = context.tokens;
    final subjects = LearningCatalog.subjectsFor(className);
    final topics = LearningCatalog.topicsFor(className, null);
    final isSelected = _selectedClass == className;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      decoration: BoxDecoration(
        color: isSelected ? t.primaryTint : t.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: isSelected ? t.primary : t.border,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: () => _selectClass(className),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: t.primaryTint,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.school,
                  color: isSelected ? t.statusPresent : t.primary,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: context.text.titleMedium?.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      '${subjects.length} subjects • ${topics.length} syllabus topics',
                      style: context.text.bodySmall?.copyWith(color: t.inkMuted),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xs,
                      children: [
                        for (final subject in subjects.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.xs,
                              vertical: AppSpace.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: subject.color.withValues(alpha: 0.2),
                              borderRadius: AppRadius.brPill,
                            ),
                            child: Text(
                              subject.name,
                              style: context.text.labelSmall?.copyWith(
                                color: subject.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
