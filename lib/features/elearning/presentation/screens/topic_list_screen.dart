import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: Text(
          _subject == null ? 'Syllabus Topics' : '$_subject Topics',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Open Shorts',
            onPressed: () => context.go('/feed'),
            icon: const Icon(Icons.smart_display),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _topics.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(22)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories, color: Colors.amberAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_selectedClass ?? 'Guest'} • ${_subject ?? 'All subjects'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < _topics.length; index++)
                  _buildTopicCard(
                    context,
                    index,
                    _topics[index],
                  ).animate().fade(delay: (index * 70).ms).slideY(begin: 0.08),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.topic_outlined, size: 72, color: Colors.white38),
            const SizedBox(height: 18),
            const Text(
              'No topics yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose a class and subject to see syllabus topics.',
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

  Widget _buildTopicCard(BuildContext context, int index, String topic) {
    final progress = index == 0 ? 1.0 : (index == 1 ? 0.55 : 0.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          '${index + 1}. $topic',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _subject == null
                  ? 'Topic-wise notes, tutor help, and related shorts.'
                  : 'From $_subject syllabus. Watch only related shorts.',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              color: progress == 1 ? Colors.tealAccent : Colors.purpleAccent,
              minHeight: 7,
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.play_circle_fill,
            color: Colors.purpleAccent,
            size: 40,
          ),
          onPressed: () => context.push(
            '/elearning-learning?topic=${Uri.encodeComponent(topic)}'
            '&subject=${Uri.encodeComponent(_subject ?? '')}',
          ),
        ),
      ),
    );
  }
}
