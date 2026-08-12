import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/local_history_store.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/ai_tool_scaffold.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';

class AiStudyPlannerScreen extends StatefulWidget {
  const AiStudyPlannerScreen({super.key});

  @override
  State<AiStudyPlannerScreen> createState() => _AiStudyPlannerScreenState();
}

class _AiStudyPlannerScreenState extends State<AiStudyPlannerScreen> {
  DateTime? _examDate;
  String? _selectedClass;
  List<SubjectSyllabus> _subjects = const [];
  bool _isGenerating = false;
  String? _error;
  List<Map<String, dynamic>> _dailyPlan = [];
  List<Map<String, dynamic>> _planHistory = [];
  static const _historyStore = LocalHistoryStore('study_planner_data');

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    if (!mounted) return;
    setState(() {
      _selectedClass = selectedClass;
      _subjects = LearningCatalog.subjectsFor(selectedClass);
    });
  }

  Future<void> _loadPlan() async {
    final history = await _historyStore.load();
    setState(() {
      _planHistory = history;
      if (_planHistory.isNotEmpty) {
        _dailyPlan = List<Map<String, dynamic>>.from(
            _planHistory.first['plan'] ?? []);
      }
    });
  }

  Future<void> _savePlan() async {
    await _historyStore.save(_planHistory);
  }

  Future<void> _generatePlan() async {
    if (_examDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exam date first')),
      );
      return;
    }
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your class first so we know your subjects')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final daysLeft = _examDate!.difference(DateTime.now()).inDays;
    final subjectList = _subjects.map((s) => s.name).join(', ');

    final prompt = "Create a study plan for $daysLeft days until the exam. "
        "Subjects: $subjectList. "
        "Generate a JSON array of daily tasks. Each object must have: "
        "\"time\" (string, e.g. '9:00 AM'), \"subject\" (string), "
        "\"task\" (string), \"duration\" (string, e.g. '45 min'), "
        "\"type\" (string, one of: study/review/practice/break). "
        "Include 6-8 tasks per day. No markdown, no code fences. Raw JSON only.";

    try {
      final result = await AiService.generateStructured(prompt);
      if (!mounted) return;

      final List<dynamic> parsed = json.decode(result);
      final plan = parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      setState(() {
        _dailyPlan = plan;
        _isGenerating = false;
      });

      _planHistory.insert(0, {
        'examDate': _examDate!.toIso8601String(),
        'plan': plan,
        'created': DateTime.now().toIso8601String(),
      });
      if (_planHistory.length > 10) _planHistory.removeLast();
      _savePlan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _error = "Couldn't generate a plan. Check your connection and try again.";
      });
    }
  }

  void _toggleTask(int index) {
    setState(() {
      _dailyPlan[index]['completed'] = !(_dailyPlan[index]['completed'] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AiToolScaffold(
      title: 'AI Study Planner',
      subtitle: 'Pick an exam date and get a day-by-day study plan.',
      inputForm: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExamDatePicker(context),
          const SizedBox(height: AppSpace.md),
          _buildSubjectList(context),
        ],
      ),
      generateLabel: 'Generate Plan',
      isGenerating: _isGenerating,
      onGenerate: _generatePlan,
      errorText: _error,
      onRetry: _generatePlan,
      resultBuilder: _dailyPlan.isNotEmpty
          ? (ctx) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressCard(ctx),
                  const SizedBox(height: AppSpace.md),
                  _buildTodayPlanCard(ctx),
                ],
              )
          : null,
    );
  }

  Widget _buildExamDatePicker(BuildContext context) {
    final t = context.tokens;
    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _examDate ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) setState(() => _examDate = date);
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Icons.calendar_today, color: t.primary, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam Date',
                  style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  _examDate != null
                      ? '${_examDate!.day}/${_examDate!.month}/${_examDate!.year}'
                      : 'Tap to select exam date',
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _examDate != null ? t.ink : t.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.inkFaint),
        ],
      ),
    );
  }

  Widget _buildSubjectList(BuildContext context) {
    final t = context.tokens;
    if (_subjects.isEmpty) {
      return NexusCard(
        onTap: () => context.push('/elearning-class'),
        child: Row(
          children: [
            Icon(Icons.school_outlined, color: t.inkMuted),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                'Select your class to plan around your real subjects',
                style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
              ),
            ),
            Icon(Icons.chevron_right, color: t.inkFaint),
          ],
        ),
      );
    }
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_selectedClass Subjects', style: context.text.titleSmall),
              GestureDetector(
                onTap: () => context.push('/elearning-class'),
                child: Text(
                  'Change',
                  style: context.text.labelMedium?.copyWith(color: t.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ...List.generate(_subjects.length, (i) {
            final subject = _subjects[i];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpace.xs),
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                children: [
                  Icon(subject.icon, color: subject.color, size: 20),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: context.typeExtras.bodyStrong.copyWith(
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xxs),
                        Text(
                          subject.topics.join(' • '),
                          style: context.text.bodySmall?.copyWith(
                            color: t.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final t = context.tokens;
    final completed =
        _dailyPlan.where((t) => t['completed'] == true).length;
    final total = _dailyPlan.length;
    final progress = total > 0 ? completed / total : 0.0;

    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      background: t.primaryTint,
      borderColor: t.primaryTintBorder,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Progress", style: context.text.titleSmall),
              Text(
                '$completed/$total tasks',
                style: context.typeExtras.bodyStrong.copyWith(
                  color: t.statusPresent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: t.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(t.statusPresent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '${(progress * 100).round()}% Complete',
            style: context.text.bodySmall?.copyWith(color: t.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayPlanCard(BuildContext context) {
    final t = context.tokens;
    final taskTypeIcons = {
      'study': Icons.menu_book,
      'review': Icons.replay,
      'practice': Icons.quiz,
      'break': Icons.coffee,
    };
    final taskTypeColors = {
      'study': t.primary,
      'review': t.statusPresent,
      'practice': t.statusLate,
      'break': t.statusPresent,
    };

    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Schedule", style: context.text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          ...List.generate(_dailyPlan.length, (i) {
            final task = _dailyPlan[i];
            final type = task['type'] ?? 'study';
            final isCompleted = task['completed'] == true;
            final color = taskTypeColors[type] ?? t.primary;
            final icon = taskTypeIcons[type] ?? Icons.circle;

            return GestureDetector(
              onTap: () => _toggleTask(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpace.xs),
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? t.statusPresent.withValues(alpha: 0.12)
                      : t.surfaceAlt,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: isCompleted
                        ? t.statusPresent.withValues(alpha: 0.3)
                        : t.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.xs),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['time'] ?? '',
                            style: context.text.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            task['task'] ?? '',
                            style: context.text.bodyMedium?.copyWith(
                              color: isCompleted ? t.inkFaint : t.ink,
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            '${task['subject']} • ${task['duration'] ?? ''}',
                            style: context.text.bodySmall?.copyWith(
                              color: t.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isCompleted ? t.statusPresent : t.inkFaint,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
