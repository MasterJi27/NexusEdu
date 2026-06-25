import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagramPracticeScreen extends StatefulWidget {
  const DiagramPracticeScreen({super.key});

  @override
  State<DiagramPracticeScreen> createState() => _DiagramPracticeScreenState();
}

class _DiagramPracticeScreenState extends State<DiagramPracticeScreen> {
  String _selectedSubject = 'Biology';
  String _selectedTopic = 'Cell Structure';
  bool _isLoading = false;
  bool _practiceStarted = false;
  bool _isChecking = false;
  bool _hasResult = false;

  final TextEditingController _descriptionController = TextEditingController();
  List<String> _expectedParts = [];
  List<String> _completedParts = [];
  List<String> _missingParts = [];
  int _score = 0;
  String _aiFeedback = '';
  List<Map<String, dynamic>> _results = [];

  final Map<String, List<String>> _topicsBySubject = {
    'Biology': [
      'Cell Structure',
      'Heart Diagram',
      'Plant Cell',
      'DNA Structure',
      'Human Brain',
    ],
    'Physics': [
      'Circuit Diagram',
      'Lens Ray Diagram',
      'Free Body Diagram',
      'Wave Motion',
      'Electromagnetic Spectrum',
    ],
    'Chemistry': [
      'Atomic Structure',
      'Periodic Table Layout',
      'Chemical Bonding',
      'Organic Molecules',
      'Lab Apparatus',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('diagram_practice') ?? [];
    setState(() {
      _results = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'diagram_practice',
      _results.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> _startPractice() async {
    setState(() => _isLoading = true);

    final prompt =
        'List the key parts/components of the $_selectedTopic diagram in $_selectedSubject. '
        'Return ONLY a comma-separated list of parts, nothing else. '
        'Example: Nucleus, Cell Membrane, Mitochondria';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      response = _getDefaultParts(_selectedTopic);
    }

    final parts = response
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _isLoading = false;
      _practiceStarted = true;
      _hasResult = false;
      _expectedParts = parts.isNotEmpty ? parts : _getDefaultParts(_selectedTopic).split(',');
      _completedParts = [];
      _missingParts = [];
      _score = 0;
      _aiFeedback = '';
      _descriptionController.clear();
    });
  }

  String _getDefaultParts(String topic) {
    switch (topic) {
      case 'Cell Structure':
        return 'Nucleus,Cell Membrane,Cytoplasm,Mitochondria,Ribosomes,Endoplasmic Reticulum,Golgi Apparatus,Lysosomes';
      case 'Heart Diagram':
        return 'Right Atrium,Left Atrium,Right Ventricle,Left Ventricle,Aorta,Pulmonary Artery,Tricuspid Valve,Mitral Valve';
      case 'Circuit Diagram':
        return 'Battery,Resistor,Switch,Wire,Bulb,Ammeter,Voltmeter,Ground';
      case 'Atomic Structure':
        return 'Nucleus,Protons,Neutrons,Electrons,Electron Shells,Valence Shell';
      default:
        return 'Component 1,Component 2,Component 3,Component 4,Component 5';
    }
  }

  Future<void> _checkDescription() async {
    if (_descriptionController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the diagram in detail')),
      );
      return;
    }

    setState(() => _isChecking = true);

    final prompt =
        'User is describing the $_selectedTopic diagram in $_selectedSubject.\n'
        'Expected parts: ${_expectedParts.join(", ")}\n'
        'User description: "${_descriptionController.text.trim()}"\n\n'
        'Check which expected parts are mentioned. '
        'Return in this format:\n'
        'FOUND: part1,part2\n'
        'MISSING: part3,part4\n'
        'SCORE: X out of ${_expectedParts.length}\n'
        'FEEDBACK: brief feedback';

    String response;
    try {
      response = await AiAgentService.callAgent(
        'custom',
        {'prompt': prompt},
      );
    } catch (_) {
      final desc = _descriptionController.text.toLowerCase();
      final found = _expectedParts
          .where((p) => desc.contains(p.toLowerCase()))
          .toList();
      final missing =
          _expectedParts.where((p) => !desc.contains(p.toLowerCase())).toList();
      response = 'FOUND: ${found.join(",")}\nMISSING: ${missing.join(",")}\n'
          'SCORE: ${found.length} out of ${_expectedParts.length}\n'
          'FEEDBACK: ${missing.isEmpty ? "Great job!" : "Review the missing parts."}';
    }

    final foundMatch = RegExp(r'FOUND:\s*(.+)').firstMatch(response);
    final missingMatch = RegExp(r'MISSING:\s*(.+)').firstMatch(response);
    final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(response);
    final feedbackMatch = RegExp(r'FEEDBACK:\s*(.+)').firstMatch(response);

    final found = foundMatch != null
        ? foundMatch.group(1)!.split(',').map((s) => s.trim()).toList()
        : [];
    final missing = missingMatch != null
        ? missingMatch.group(1)!.split(',').map((s) => s.trim()).toList()
        : _expectedParts.toList();
    final score = scoreMatch != null ? int.tryParse(scoreMatch.group(1)!) ?? 0 : 0;
    final feedback = feedbackMatch?.group(1)?.trim() ?? '';

    final result = {
      'subject': _selectedSubject,
      'topic': _selectedTopic,
      'score': score,
      'total': _expectedParts.length,
      'completed': found,
      'missing': missing,
      'feedback': feedback,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _completedParts = List<String>.from(found);
      _missingParts = List<String>.from(missing);
      _score = score;
      _aiFeedback = feedback;
      _isChecking = false;
      _hasResult = true;
    });

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Diagram Practice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _practiceStarted ? _buildPracticeView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubjectSelector(),
          const SizedBox(height: 16),
          _buildTopicSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startPractice,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
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
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.schema),
              label: Text(
                _isLoading ? 'Loading...' : 'Start Practice',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Practice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_results.length.clamp(0, 10), (i) {
              return _buildResultCard(_results[i]);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildSelectorRow(
      'Subject',
      ['Biology', 'Physics', 'Chemistry'],
      _selectedSubject,
      (val) => setState(() {
        _selectedSubject = val!;
        _selectedTopic =
            (_topicsBySubject[_selectedSubject] ?? ['Cell Structure']).first;
      }),
    );
  }

  Widget _buildTopicSelector() {
    final topics = _topicsBySubject[_selectedSubject] ?? ['Cell Structure'];
    return _buildSelectorRow(
      'Topic',
      topics,
      _selectedTopic,
      (val) => setState(() => _selectedTopic = val!),
    );
  }

  Widget _buildSelectorRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                      fontSize: 12,
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

  Widget _buildPracticeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schema,
                        color: Colors.deepPurpleAccent.withAlpha(200)),
                    const SizedBox(width: 8),
                    Text(
                      '$_selectedTopic Diagram',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Expected Parts:',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _expectedParts.map((part) {
                    final isCompleted = _completedParts.contains(part);
                    final isMissing = _hasResult && _missingParts.contains(part);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.greenAccent.withAlpha(30)
                            : isMissing
                                ? Colors.redAccent.withAlpha(30)
                                : Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.greenAccent
                              : isMissing
                                  ? Colors.redAccent
                                  : Colors.white.withAlpha(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_circle
                                : isMissing
                                    ? Icons.cancel
                                    : Icons.radio_button_unchecked,
                            color: isCompleted
                                ? Colors.greenAccent
                                : isMissing
                                    ? Colors.redAccent
                                    : Colors.white38,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            part,
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.greenAccent
                                  : isMissing
                                      ? Colors.redAccent
                                      : Colors.white.withAlpha(150),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Describe the diagram in detail. Mention all parts you know, their positions, and functions...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withAlpha(15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withAlpha(15)),
              ),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isChecking ? null : _checkDescription,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurpleAccent.withAlpha(220),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isChecking ? 'Checking...' : 'Check Accuracy',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_hasResult) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Score: ',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      Text(
                        '$_score/${_expectedParts.length}',
                        style: TextStyle(
                          color: _score == _expectedParts.length
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  if (_aiFeedback.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _aiFeedback,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fade(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schema,
                color: Colors.deepPurpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['subject']} - ${r['topic']}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Parts: ${r['score']}/${r['total']} completed',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${r['score']}/${r['total']}',
            style: TextStyle(
              color: r['score'] == r['total']
                  ? Colors.greenAccent
                  : Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
