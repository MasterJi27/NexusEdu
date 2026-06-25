import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyGroupScreen extends StatefulWidget {
  const StudyGroupScreen({super.key});

  @override
  State<StudyGroupScreen> createState() => _StudyGroupScreenState();
}

class _StudyGroupScreenState extends State<StudyGroupScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isMatching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('study_groups');
    if (raw != null) {
      _groups = raw
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _groups.map((e) => json.encode(e)).toList();
    await prefs.setStringList('study_groups', encoded);
  }

  Future<void> _findStudyGroup() async {
    setState(() => _isMatching = true);
    final response = await AiService.sendMessageToTutor(
      "Generate a study group match for a student. Return JSON with: "
      "\"name\" (group name), \"subject\" (subject), "
      "\"members\" (list of 3 objects with \"name\" and \"strength\"), "
      "\"complementarySkills\" (list of 3 strings). "
      "Return only raw JSON, no markdown.",
    );
    try {
      String cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        cleaned = lines.join('\n').trim();
      }
      final parsed = json.decode(cleaned);
      if (parsed is Map<String, dynamic>) {
        parsed['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        parsed['streak'] = 0;
        parsed['messages'] = <dynamic>[];
        parsed['createdAt'] = DateTime.now().toIso8601String();
        setState(() {
          _groups.insert(0, parsed);
          _isMatching = false;
        });
        _saveGroups();
        return;
      }
    } catch (_) {}
    final fallback = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': 'Study Squad ${_groups.length + 1}',
      'subject': 'Mathematics',
      'members': [
        {'name': 'Arjun', 'strength': 'Algebra'},
        {'name': 'Priya', 'strength': 'Geometry'},
        {'name': 'You', 'strength': 'Calculus'},
      ],
      'complementarySkills': [
        'Strong visualization',
        'Problem decomposition',
        'Pattern recognition',
      ],
      'streak': 0,
      'messages': <dynamic>[],
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() {
      _groups.insert(0, fallback);
      _isMatching = false;
    });
    _saveGroups();
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    String selectedSubject = 'Mathematics';
    final subjects = [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'English',
      'History',
      'Computer Science',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Create Study Group',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSubject,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Subject',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedSubject = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final group = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': name,
                  'subject': selectedSubject,
                  'members': [
                    {'name': 'You', 'strength': selectedSubject},
                  ],
                  'complementarySkills': <String>[],
                  'streak': 0,
                  'messages': <dynamic>[],
                  'createdAt': DateTime.now().toIso8601String(),
                };
                setState(() => _groups.insert(0, group));
                _saveGroups();
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupChat(int index) {
    final group = _groups[index];
    final messages = List<Map<String, dynamic>>.from(group['messages'] ?? []);
    final chatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F13),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                group['name'] ?? 'Group Chat',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: messages.length,
                itemBuilder: (ctx, i) {
                  final msg = messages[i];
                  final isMe = msg['sender'] == 'You';
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.deepPurpleAccent.withAlpha(40)
                            : Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              msg['sender'] ?? '',
                              style: const TextStyle(
                                color: Colors.deepPurpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            msg['text'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withAlpha(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      final text = chatController.text.trim();
                      if (text.isEmpty) return;
                      chatController.clear();
                      setState(() {
                        messages.add({
                          'sender': 'You',
                          'text': text,
                          'time': DateTime.now().toIso8601String(),
                        });
                        _groups[index]['messages'] = messages;
                      });
                      _saveGroups();
                      Future.delayed(const Duration(milliseconds: 800), () {
                        final replies = [
                          'Great point! Let me think about that.',
                          'I agree, that makes sense.',
                          'Can you explain that again?',
                          'Nice! I was stuck on that part.',
                          'Let\'s review this together.',
                        ];
                        final reply = replies[
                            (DateTime.now().millisecondsSinceEpoch %
                                    replies.length)
                                .toInt()];
                        setState(() {
                          messages.add({
                            'sender':
                                (_groups[index]['members'] as List).length > 1
                                    ? (_groups[index]['members'] as List)[1]
                                        ['name']
                                    : 'Member',
                            'text': reply,
                            'time': DateTime.now().toIso8601String(),
                          });
                          _groups[index]['messages'] = messages;
                        });
                        _saveGroups();
                      });
                    },
                    icon: const Icon(Icons.send,
                        color: Colors.deepPurpleAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _incrementStreak(int index) {
    setState(() {
      _groups[index]['streak'] = (_groups[index]['streak'] ?? 0) + 1;
    });
    _saveGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Study Groups',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
            onPressed: _showCreateGroupDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent))
          : _groups.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) => _buildGroupCard(i),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isMatching ? null : _findStudyGroup,
        backgroundColor: Colors.deepPurpleAccent,
        icon: _isMatching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          _isMatching ? 'Matching...' : 'Find Study Group',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ).animate().fade(delay: 300.ms),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, size: 80, color: Colors.white.withAlpha(30)),
          const SizedBox(height: 24),
          Text(
            'No Study Groups Yet',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find or create a group to start\nstudying with peers',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _findStudyGroup,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Find Study Group'),
          ),
        ],
      ).animate().fade().slideY(begin: 0.1),
    );
  }

  Widget _buildGroupCard(int index) {
    final group = _groups[index];
    final members = List<Map<String, dynamic>>.from(group['members'] ?? []);
    final streak = group['streak'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    group['subject'] ?? 'General',
                    style: const TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (streak > 0)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              group['name'] ?? 'Untitled Group',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: members
                  .map((m) => Chip(
                        label: Text(
                          '${m['name']} · ${m['strength']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: Colors.white.withAlpha(15),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGroupChat(index),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurpleAccent,
                      side: BorderSide(
                          color: Colors.deepPurpleAccent.withAlpha(60)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _incrementStreak(index),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Study Done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent.withAlpha(60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fade(delay: (80 * index).ms).slideY(begin: 0.05);
  }
}
