import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Choose Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(22)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.route, color: Colors.amberAccent, size: 30),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Class selection locks Shorts, topics, and certificates to your syllabus.',
                          style: TextStyle(color: Colors.white70, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final className in LearningCatalog.classes)
                  _buildClassCard(
                    className,
                  ).animate().fade().slideY(begin: 0.08),
              ],
            ),
    );
  }

  Widget _buildClassCard(String className) {
    final subjects = LearningCatalog.subjectsFor(className);
    final topics = LearningCatalog.topicsFor(className, null);
    final isSelected = _selectedClass == className;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.deepPurpleAccent.withAlpha(42)
            : Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? Colors.deepPurpleAccent
              : Colors.white.withAlpha(24),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectClass(className),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(32),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.school,
                  color: isSelected
                      ? Colors.tealAccent
                      : Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${subjects.length} subjects • ${topics.length} syllabus topics',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final subject in subjects.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: subject.color.withAlpha(32),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              subject.name,
                              style: TextStyle(
                                color: subject.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
