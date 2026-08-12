import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

class SubjectSelectionScreen extends StatefulWidget {
  const SubjectSelectionScreen({super.key});

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  String? _selectedClass;
  List<SubjectSyllabus> _subjects = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    if (!mounted) return;
    setState(() {
      _selectedClass = selectedClass;
      _subjects = LearningCatalog.subjectsFor(selectedClass);
      _isLoading = false;
    });
  }

  void _openSubject(String subjectName) {
    context.push(
      '/elearning-topic?subject=${Uri.encodeComponent(subjectName)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleText = _selectedClass == null
        ? 'Select Subject'
        : '$_selectedClass Subjects';
    return NexusScreen(
      title: titleText,
      titleWidget: Text(
        titleText,
        style: context.text.titleMedium?.copyWith(color: t.ink),
      ),
      actions: [
        IconButton(
          tooltip: 'Change class',
          onPressed: () => context.push('/elearning-class'),
          icon: const Icon(Icons.school_outlined),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
          ? _buildNoClassState(context)
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpace.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpace.sm,
                mainAxisSpacing: AppSpace.sm,
                childAspectRatio: 0.82,
              ),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                return _buildSubjectCard(context, subject);
              },
            ),
    );
  }

  Widget _buildNoClassState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: NexusStateView.empty(
          title: 'Select a class first',
          description: 'Subjects and topics are loaded from the selected syllabus.',
          icon: Icons.school_outlined,
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectSyllabus subject) {
    final t = context.tokens;
    return InkWell(
      onTap: () => _openSubject(subject.name),
      borderRadius: AppRadius.brLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: subject.color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: subject.color.withValues(alpha: 0.16),
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(subject.icon, color: subject.color, size: 30),
            ),
            const Spacer(),
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '${subject.topics.length} chapters',
              style: context.text.labelMedium?.copyWith(
                color: subject.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              subject.topics.take(2).join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: t.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
