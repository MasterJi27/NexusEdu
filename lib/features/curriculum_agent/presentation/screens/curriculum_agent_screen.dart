import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

class CurriculumAgentScreen extends StatefulWidget {
  const CurriculumAgentScreen({super.key});

  @override
  State<CurriculumAgentScreen> createState() => _CurriculumAgentScreenState();
}

class _CurriculumAgentScreenState extends State<CurriculumAgentScreen> {
  bool _isScanning = false;
  String _selectedSubject = 'Computer Science';
  final _subjects = [
    'Computer Science', 'Physics', 'Chemistry', 'Mathematics',
    'Biology', 'History', 'Economics', 'English Literature',
  ];
  int _selectedTopicIndex = -1;
  String _topicContent = '';

  List<Map<String, dynamic>> get _curriculum => AppSettings.instance.curriculum;

  void _refresh() => setState(() {});

  Future<void> _scanCurriculum() async {
    setState(() => _isScanning = true);
    final result = await AiService.generateCurriculum(_selectedSubject);
    if (!mounted) return;
    setState(() => _isScanning = false);

    List<dynamic> topics;
    try {
      topics = json.decode(result) as List<dynamic>;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse curriculum: $result')),
      );
      return;
    }

    final curriculumList = topics
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();

    await AppSettings.instance.saveCurriculum(curriculumList);
    _refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Curriculum generated: ${curriculumList.length} topics')),
    );
  }

  Future<void> _loadTopicContent(int index) async {
    final topic = _curriculum[index]['title'] as String;
    setState(() {
      _selectedTopicIndex = index;
      _topicContent = 'Loading...';
    });
    final content = await AiService.generateCurriculumContent(topic);
    if (!mounted) return;
    setState(() => _topicContent = content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Assembling AI', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: _scanCurriculum,
              tooltip: 'Scan & Generate Curriculum',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.withAlpha(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors, color: Colors.deepPurpleAccent, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Autonomous AI Agent',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Scans emerging research, job trends & curriculum changes. Self-generates your syllabus.',
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                  ),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSubject = v);
                  },
                ),
              ],
            ),
          ),
          if (_curriculum.isEmpty && !_isScanning)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar, size: 80, color: Colors.white.withAlpha(80)),
                    const SizedBox(height: 16),
                    Text('No curriculum generated yet',
                        style: TextStyle(fontSize: 20, color: Colors.white.withAlpha(150))),
                    const SizedBox(height: 8),
                    Text('Tap the sparkle icon to scan & generate',
                        style: TextStyle(color: Colors.white.withAlpha(100))),
                  ],
                ),
              ),
            )
          else if (_isScanning)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI scanning internet for trends...'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _curriculum.length,
                      itemBuilder: (context, index) {
                        final topic = _curriculum[index];
                        final isSelected = _selectedTopicIndex == index;
                        final isEmerging = topic['emerging'] == true;
                        return Card(
                          color: isSelected ? Colors.deepPurple.withAlpha(50) : const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            leading: isEmerging
                                ? const Icon(Icons.bolt, color: Colors.amberAccent, size: 18)
                                : Icon(Icons.menu_book, color: Colors.white54, size: 18),
                            title: Text(
                              topic['title'] ?? '',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              topic['difficulty'] ?? '',
                              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(120)),
                            ),
                            onTap: () => _loadTopicContent(index),
                          ),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _topicContent.isEmpty
                        ? Center(
                            child: Text('Select a topic to view content',
                                style: TextStyle(color: Colors.white.withAlpha(120))),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(_topicContent),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
