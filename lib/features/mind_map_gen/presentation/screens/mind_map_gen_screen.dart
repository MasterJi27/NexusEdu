import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindMapGenScreen extends StatefulWidget {
  const MindMapGenScreen({super.key});

  @override
  State<MindMapGenScreen> createState() => _MindMapGenScreenState();
}

class _MindMapGenScreenState extends State<MindMapGenScreen> {
  final TextEditingController _topicController = TextEditingController();
  int _selectedDepth = 3;
  bool _isLoading = false;
  String _rawMindMap = '';
  Map<String, dynamic>? _parsedTree;
  List<Map<String, dynamic>> _savedMindMaps = [];

  static const List<Color> _branchColors = [
    Colors.deepPurpleAccent,
    Colors.tealAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.lightGreenAccent,
    Colors.cyanAccent,
    Colors.amberAccent,
    Colors.redAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('mind_maps') ?? [];
    setState(() {
      _savedMindMaps = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateMindMap() async {
    if (_topicController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _rawMindMap = '';
      _parsedTree = null;
    });

    final result = await AiAgentService.callAgent('mind_map', {
      'topic': _topicController.text.trim(),
      'subject': 'General',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _rawMindMap = result;
      _parsedTree = _parseMindMap(result);
    });

    _savedMindMaps.insert(0, {
      'topic': _topicController.text.trim(),
      'depth': _selectedDepth,
      'content': _rawMindMap,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedMindMaps.length > 50) _savedMindMaps.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'mind_maps',
      _savedMindMaps.map((e) => json.encode(e)).toList(),
    );
  }

  Map<String, dynamic> _parseMindMap(String text) {
    final lines = text.split('\n');
    final root = <String, dynamic>{'children': <Map<String, dynamic>>[]};
    final stack = [{'node': root, 'indent': -1}];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final indent = line.length - line.trimLeft().length;
      final content = line.trim().replaceFirst(RegExp(r'^[-*>#\s]+'), '').trim();
      if (content.isEmpty) continue;

      while (stack.length > 1 && (stack.last['indent'] as int) >= indent) {
        stack.removeLast();
      }

      final node = {'name': content, 'children': <Map<String, dynamic>>[]};
      ((stack.last['node']! as Map)['children'] as List).add(node);
      stack.add({'node': node, 'indent': indent});
    }

    return root;
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Mind Map Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topic',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Photosynthesis, Solar System...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(),
            const SizedBox(height: 12),
            _buildDepthSelector(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateMindMap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurpleAccent.withAlpha(200),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.account_tree),
                label: Text(
                  _isLoading ? 'Generating Mind Map...' : 'Generate Mind Map',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 30),
              const Center(
                child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
              ),
            ],
            if (_parsedTree != null) ...[
              const SizedBox(height: 20),
              _buildMindMapVisualization(),
            ],
            if (_savedMindMaps.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Mind Maps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedMindMaps.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedMindMaps[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDepthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Depth Levels',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [3, 4, 5].map((depth) {
              final isSelected = depth == _selectedDepth;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDepth = depth),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepPurpleAccent.withAlpha(40)
                          : Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurpleAccent
                            : Colors.white.withAlpha(15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$depth Levels',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.deepPurpleAccent
                              : Colors.white.withAlpha(150),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildMindMapVisualization() {
    final children = _parsedTree!['children'] as List? ?? [];
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurpleAccent, Color(0xFF6200EA)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _topicController.text.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(children.length, (i) {
            return _buildBranch(
              children[i] as Map<String, dynamic>,
              _branchColors[i % _branchColors.length],
              0,
            );
          }),
        ],
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildBranch(Map<String, dynamic> node, Color color, int depth) {
    final children = node['children'] as List? ?? [];
    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0 + 8, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(40)),
                  ),
                  child: Text(
                    node['name'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: depth == 0 ? 14 : 12,
                      fontWeight:
                          depth == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (children.isNotEmpty)
            ...List.generate(children.length, (i) {
              return _buildBranch(
                children[i] as Map<String, dynamic>,
                color,
                depth + 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSavedItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['topic'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item['depth']} levels deep',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedMindMaps.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'mind_maps',
                    _savedMindMaps.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
