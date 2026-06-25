import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioNotesScreen extends StatefulWidget {
  const AudioNotesScreen({super.key});

  @override
  State<AudioNotesScreen> createState() => _AudioNotesScreenState();
}

class _AudioNotesScreenState extends State<AudioNotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  String _voiceSpeed = 'Normal';
  bool _isLoading = false;
  String _formattedNotes = '';
  List<Map<String, dynamic>> _savedNotes = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('audio_notes') ?? [];
    setState(() {
      _savedNotes = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _generateAudioNotes() async {
    if (_notesController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _formattedNotes = '';
    });

    final speedHint = _voiceSpeed == 'Slow'
        ? 'Use short sentences, repeat key points, speak slowly.'
        : _voiceSpeed == 'Fast'
            ? 'Use concise phrasing, skip filler, quick pacing.'
            : 'Use natural pacing, conversational tone.';

    final result = await AiAgentService.callAgent('custom', {
      'prompt':
          'Reformat these notes for audio listening at $_voiceSpeed speed. '
              '$speedHint\n\n'
              'Add emphasis markers like [EMPHASIZE], [PAUSE], [REPEAT] '
              'and structure it with clear transitions.\n\n'
              'Original notes:\n${_notesController.text.trim()}',
    });

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _formattedNotes = result;
    });

    _savedNotes.insert(0, {
      'original': _notesController.text.trim(),
      'formatted': _formattedNotes,
      'speed': _voiceSpeed,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_savedNotes.length > 50) _savedNotes.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'audio_notes',
      _savedNotes.map((e) => json.encode(e)).toList(),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Audio Notes',
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
                    'Paste your notes content',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Paste your study notes here...',
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
            _buildVoiceSelector(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generateAudioNotes,
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
                    : const Icon(Icons.headphones),
                label: Text(
                  _isLoading ? 'Generating Audio Notes...' : 'Generate Audio Notes',
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
            if (_formattedNotes.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildFormattedCard(),
            ],
            if (_savedNotes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saved Audio Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(_savedNotes.length.clamp(0, 10), (i) {
                return _buildSavedItem(_savedNotes[i], i);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSelector() {
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
            'Voice Speed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Slow', 'Normal', 'Fast'].map((speed) {
              final isSelected = speed == _voiceSpeed;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _voiceSpeed = speed),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          speed == 'Slow'
                              ? Icons.speed
                              : speed == 'Normal'
                                  ? Icons.speed_rounded
                                  : Icons.fast_forward,
                          color: isSelected
                              ? Colors.deepPurpleAccent
                              : Colors.white.withAlpha(150),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          speed,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.deepPurpleAccent
                                : Colors.white.withAlpha(150),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  Widget _buildFormattedCard() {
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
              const Icon(Icons.headphones, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Formatted for Listening',
                  style: TextStyle(
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
            _formattedNotes,
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
          Icon(Icons.headphones, color: Colors.deepPurpleAccent.withAlpha(150), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['speed']} Speed',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item['original'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withAlpha(150), size: 18),
            onPressed: () {
              setState(() => _savedNotes.removeAt(index));
              final prefs = SharedPreferences.getInstance();
              prefs.then((p) => p.setStringList(
                    'audio_notes',
                    _savedNotes.map((e) => json.encode(e)).toList(),
                  ));
            },
          ),
        ],
      ),
    );
  }
}
