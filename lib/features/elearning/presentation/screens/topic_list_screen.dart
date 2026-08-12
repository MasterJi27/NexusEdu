import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  String? _selectedClass;
  String? _subject;
  List<String> _topics = const [];
  bool _isLoading = true;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    if (!mounted) return;
    final subject = GoRouterState.of(context).uri.queryParameters['subject'];
    setState(() {
      _selectedClass = selectedClass;
      _subject = subject;
      _topics = LearningCatalog.topicsFor(selectedClass, subject);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: _subject == null ? 'Syllabus Topics' : '$_subject Topics',
      titleWidget: Text(
        _subject == null ? 'Syllabus Topics' : '$_subject Topics',
        style: context.text.titleMedium?.copyWith(color: t.ink),
      ),
      actions: [
        IconButton(
          tooltip: 'Open Shorts',
          onPressed: () => context.go('/feed'),
          icon: const Icon(Icons.smart_display),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _topics.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm,
                AppSpace.md,
                AppSpace.lg,
              ),
              children: [
                _buildClassBanner(context),
                const SizedBox(height: AppSpace.md),
                for (var index = 0; index < _topics.length; index++)
                  _buildTopicCard(context, index, _topics[index]),
              ],
            ),
    );
  }

  Widget _buildClassBanner(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_stories, color: t.secondaryFill),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              '${_selectedClass ?? 'Guest'} • ${_subject ?? 'All subjects'}',
              style: context.text.titleSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: NexusStateView.empty(
          title: 'No topics yet',
          description: 'Choose a class and subject to see syllabus topics.',
          icon: Icons.topic_outlined,
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, int index, String topic) {
    final t = context.tokens;
    final progress = index == 0 ? 1.0 : (index == 1 ? 0.55 : 0.0);
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.md),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          '${index + 1}. $topic',
          style: context.text.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpace.xs),
            Text(
              _subject == null
                  ? 'Topic-wise notes, tutor help, and related shorts.'
                  : 'From $_subject syllabus. Watch only related shorts.',
              style: context.text.bodySmall?.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: AppSpace.sm),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: t.surfaceAlt,
              color: progress == 1 ? t.statusPresent : t.primary,
              minHeight: 7,
              borderRadius: AppRadius.brPill,
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.play_circle_fill,
            color: t.primary,
            size: 40,
          ),
          onPressed: () => context.push(
            '/elearning-learning?topic=${Uri.encodeComponent(topic)}'
            '&subject=${Uri.encodeComponent(_subject ?? '')}',
          ),
        ),
        onTap: () => context.push(
          '/elearning-learning?topic=${Uri.encodeComponent(topic)}'
          '&subject=${Uri.encodeComponent(_subject ?? '')}',
        ),
      ),
    );
  }
}
