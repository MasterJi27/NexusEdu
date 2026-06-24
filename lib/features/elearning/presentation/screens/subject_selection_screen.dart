import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: Text(
          _selectedClass == null
              ? 'Select Subject'
              : '$_selectedClass Subjects',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Change class',
            onPressed: () => context.push('/elearning-class'),
            icon: const Icon(Icons.school_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
          ? _buildNoClassState(context)
          : GridView.builder(
              padding: const EdgeInsets.all(18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                return _buildSubjectCard(
                  subject,
                ).animate().scale(delay: (index * 70).ms).fade();
              },
            ),
    );
  }

  Widget _buildNoClassState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 72, color: Colors.white38),
            const SizedBox(height: 18),
            const Text(
              'Select a class first',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Subjects and topics are loaded from the selected syllabus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => context.push('/elearning-class'),
              icon: const Icon(Icons.school),
              label: const Text('Choose Class'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(SubjectSyllabus subject) {
    return InkWell(
      onTap: () => _openSubject(subject.name),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: subject.color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: subject.color.withAlpha(28),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(subject.icon, color: subject.color, size: 30),
            ),
            const Spacer(),
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${subject.topics.length} chapters',
              style: TextStyle(
                color: subject.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subject.topics.take(2).join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
