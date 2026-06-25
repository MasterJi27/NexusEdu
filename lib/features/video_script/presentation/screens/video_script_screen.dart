import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoScriptScreen extends StatefulWidget {
  const VideoScriptScreen({super.key});

  @override
  State<VideoScriptScreen> createState() => _VideoScriptScreenState();
}

class _VideoScriptScreenState extends State<VideoScriptScreen> {
  final TextEditingController _topicController = TextEditingController();
  String _selectedDuration = '5 min';
  String _selectedStyle = 'Educational';
  bool _isLoading = false;
  String _generatedScript = '';
  int _wordCount = 0;
  List<Map<String, dynamic>> _savedScripts = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('video_scripts') ?? [];
    setState(() {
      _savedScripts = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateScript() async {
    if (_topicController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _generatedScript = '';
      _wordCount = 0;
    });

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Write a $_selectedDuration $_selectedStyle video script on '
              '"${_topicController.text.trim()}". '
              'Format with: HOOK (first 5 seconds), INTRO, MAIN CONTENT '
              '(with key points), and CALL TO ACTION. '
              'Include visual cues in [brackets] and timing markers. '
              'Make it engaging and natural to speak.',
    });

    if (!mounted) return;
    final words = result.split(RegExp(r'\s+')).length;
    setState(() {
      _isLoading = false;
      _generatedScript = result;
      _wordCount = words;
    });

    _savedScripts.insert(0, {
      'topic': _topicController.text.trim(),
      'duration': _selectedDuration,
      'style': _selectedStyle,
      'content': _generatedScript,
      'wordCount': _wordCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedScripts.length > 50) _savedScripts.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'video_scripts',
      _savedScripts.map((e) => json.encode(e)).toList(),
    );
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
          'Video Script Writer',
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
                    'Video Topic',
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
                      hintText: 'e.g. Photosynthesis, World War 2...',
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
            _buildSelectorRow(
              'Duration',
              ['1 min', '3 min', '5 min', '10 min', '15 min'],
              _selectedDuration,
              (val) => setState(() => _selectedDuration = val!),
            ),
            const SizedBox(height: 12),
            _buildSelectorRow(
              'Style',
              ['Educational', 'Entertainment', 'Motivational', 'Explainer', 'Storytelling'],
              _selectedStyle,
              (val) => setState(() => _selectedStyle = val!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateScript,
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
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Generating Script...' : 'Generate Script',
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
            if (_generatedScript.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildStatsCard(),
              const SizedBox(height: 12),
              _buildScriptCard(),
            ],
            if (_savedScripts.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Scripts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedScripts.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedScripts[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  Widget _buildStatsCard() {
    final estimatedMinutes = (_wordCount / 150).ceil();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.text_fields, 'Words', '$_wordCount'),
          _buildStatItem(Icons.timer, 'Est. Duration', '~$estimatedMinutes min'),
          _buildStatItem(Icons.style, 'Style', _selectedStyle),
        ],
      ),
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurpleAccent, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(120),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildScriptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Video Script',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          SelectableText(
            _generatedScript,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.05);
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
          Icon(Icons.videocam, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
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
                  '${item['duration']} | ${item['style']} | ${item['wordCount']} words',
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
              setState(() => _savedScripts.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'video_scripts',
                    _savedScripts.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
