import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartRevisionScreen extends StatefulWidget {
  const SmartRevisionScreen({super.key});

  @override
  State<SmartRevisionScreen> createState() => _SmartRevisionScreenState();
}

class _SmartRevisionScreenState extends State<SmartRevisionScreen> {
  String _revisionMode = '3-hour';
  String _selectedSubject = 'Physics';
  bool _isGenerating = false;
  List<Map<String, dynamic>> _keyPoints = [];
  int _currentCardIndex = 0;
  bool _showAnswer = false;
  int _reviewedCount = 0;
  List<Map<String, dynamic>> _revisionHistory = [];

  static const List<String> _subjects = [
    'Physics',
    'Chemistry',
    'Biology',
    'Maths',
    'English',
    'Hindi',
  ];

  static const Map<String, String> _modeDescriptions = {
    '1-hour': 'Quick 60-minute focused revision',
    '3-hour': 'Comprehensive 3-hour revision session',
    'Overnight': 'Full overnight intensive revision',
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('revision_history') ?? [];
    setState(() {
      _revisionHistory = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'revision_history',
      _revisionHistory.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _startRevision() async {
    setState(() {
      _isGenerating = true;
      _keyPoints = [];
      _currentCardIndex = 0;
      _showAnswer = false;
      _reviewedCount = 0;
    });

    final prompt = "Generate key points for a $_revisionMode revision of $_selectedSubject. "
        "Return a JSON array of objects. Each object must have: "
        "\"topic\" (string), \"keyPoint\" (string, the main concept to remember), "
        "\"detail\" (string, brief explanation), "
        "\"importance\" (string, one of: Critical/Important/Review). "
        "Generate 15-20 key points covering the most important topics. "
        "No markdown, no code fences. Raw JSON only.";

    final result = await AiService.generateCurriculumContent(prompt);

    if (!mounted) return;

    try {
      String jsonStr = result.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        jsonStr = lines.join('\n').trim();
      }

      final List<dynamic> parsed = json.decode(jsonStr);
      setState(() {
        _keyPoints = parsed
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isGenerating = false;
      });

      _revisionHistory.insert(0, {
        'subject': _selectedSubject,
        'mode': _revisionMode,
        'count': _keyPoints.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (_revisionHistory.length > 20) _revisionHistory.removeLast();
      _saveHistory();
    } catch (_) {
      setState(() => _isGenerating = false);
    }
  }

  void _nextCard() {
    if (_currentCardIndex < _keyPoints.length - 1) {
      setState(() {
        _currentCardIndex++;
        _showAnswer = false;
        _reviewedCount++;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _showAnswer = false;
      });
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.celebration, color: Colors.tealAccent, size: 48),
            SizedBox(height: 8),
            Text(
              'Revision Complete!',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'You reviewed ${_keyPoints.length} key points in $_selectedSubject.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withAlpha(180)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _keyPoints.clear());
            },
            child: const Text('Done',
                style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Smart Revision',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _keyPoints.isNotEmpty ? _buildReviewView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeSelector(),
          const SizedBox(height: 16),
          _buildSubjectSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _startRevision,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.replay),
              label: Text(
                _isGenerating ? 'Generating Key Points...' : 'Start Revision',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_revisionHistory.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Revision History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_revisionHistory.length.clamp(0, 10), (i) {
              return _buildHistoryItem(_revisionHistory[i], i);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revision Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...['1-hour', '3-hour', 'Overnight'].map((mode) {
            final isSelected = _revisionMode == mode;
            return GestureDetector(
              onTap: () => setState(() => _revisionMode = mode),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurpleAccent.withAlpha(30)
                      : Colors.black.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.deepPurpleAccent
                        : Colors.white.withAlpha(15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode == '1-hour'
                          ? Icons.timer
                          : mode == '3-hour'
                              ? Icons.hourglass_top
                              : Icons.nightlight_round,
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withAlpha(100),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.deepPurpleAccent
                                  : Colors.white.withAlpha(200),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _modeDescriptions[mode] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(120),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Colors.deepPurpleAccent),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fade().slideY(begin: -0.06);
  }

  Widget _buildSubjectSelector() {
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
            'Subject',
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
            children: _subjects.map((subject) {
              final isSelected = subject == _selectedSubject;
              return GestureDetector(
                onTap: () => setState(() => _selectedSubject = subject),
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
                    subject,
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
    ).animate().fade(delay: 100.ms);
  }

  Widget _buildReviewView() {
    final point = _keyPoints[_currentCardIndex];
    final importance = point['importance'] ?? 'Review';
    final importanceColor = importance == 'Critical'
        ? Colors.redAccent
        : importance == 'Important'
            ? Colors.orangeAccent
            : Colors.greenAccent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentCardIndex + 1}/${_keyPoints.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: importanceColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      importance,
                      style: TextStyle(
                        color: importanceColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Reviewed: $_reviewedCount',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentCardIndex + 1) / _keyPoints.length,
                backgroundColor: Colors.white.withAlpha(15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey('$_currentCardIndex-$_showAnswer'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _showAnswer
                        ? Colors.tealAccent.withAlpha(15)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _showAnswer
                          ? Colors.tealAccent.withAlpha(40)
                          : Colors.white.withAlpha(15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        point['topic'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withAlpha(120),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _showAnswer
                            ? (point['detail'] ?? '')
                            : (point['keyPoint'] ?? ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _showAnswer
                            ? 'Tap to see question'
                            : 'Tap to reveal explanation',
                        style: TextStyle(
                          color: Colors.white.withAlpha(80),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentCardIndex > 0 ? _previousCard : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                        color: Colors.white.withAlpha(40)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _nextCard,
                  icon: Icon(
                    _currentCardIndex < _keyPoints.length - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                    size: 18,
                  ),
                  label: Text(
                    _currentCardIndex < _keyPoints.length - 1
                        ? 'Next'
                        : 'Finish',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: Colors.white.withAlpha(80), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['subject']} - ${item['mode']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item['count']} key points',
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
              setState(() => _revisionHistory.removeAt(index));
              _saveHistory();
            },
          ),
        ],
      ),
    );
  }
}
