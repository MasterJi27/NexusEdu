import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabSimulatorScreen extends StatefulWidget {
  const LabSimulatorScreen({super.key});

  @override
  State<LabSimulatorScreen> createState() => _LabSimulatorScreenState();
}

class _LabSimulatorScreenState extends State<LabSimulatorScreen> {
  String _selectedSubject = 'Chemistry';
  String _selectedExperiment = '';
  bool _isLoading = false;
  bool _labStarted = false;
  bool _labComplete = false;

  final TextEditingController _observationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _guide = '';
  List<String> _steps = [];
  List<Map<String, dynamic>> _observations = [];
  String _conclusion = '';
  List<Map<String, dynamic>> _pastSessions = [];

  final Map<String, List<String>> _experimentsBySubject = {
    'Chemistry': [
      'Acid-Base Titration',
      'Salt Analysis',
      'Electrolysis of Water',
      'Rusting of Iron',
      'pH Testing of Household Items',
    ],
    'Physics': [
      'Simple Pendulum',
      'Ohm\'s Law Verification',
      'Convex Lens Image Formation',
      'Newton\'s Laws with Ramp',
      'Speed of Sound Measurement',
    ],
    'Biology': [
      'Microscope Observation of Cells',
      'Enzyme Action on Starch',
      'Osmosis with Potato',
      'Leaf Structure Study',
      'Blood Group Identification',
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedExperiment = _experimentsBySubject[_selectedSubject]!.first;
    _loadSessions();
  }

  @override
  void dispose() {
    _observationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('lab_sessions') ?? [];
    setState(() {
      _pastSessions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getStringList('lab_sessions') ?? [];
    sessions.add(json.encode({
      'subject': _selectedSubject,
      'experiment': _selectedExperiment,
      'observations': _observations,
      'conclusion': _conclusion,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (sessions.length > 20) sessions.removeAt(0);
    await prefs.setStringList('lab_sessions', sessions);
    _loadSessions();
  }

  Future<void> _startLab() async {
    setState(() {
      _isLoading = true;
      _labStarted = false;
      _labComplete = false;
      _steps = [];
      _observations = [];
      _conclusion = '';
    });

    try {
      final result = await AiAgentService.callAgent(
        'lab_experiment',
        {
          'experiment': _selectedExperiment,
          'subject': _selectedSubject,
        },
      );
      _guide = result;
      _steps = result
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
    } catch (_) {
      _guide = 'Aim: Study $_selectedExperiment\n'
          'Materials: Standard $_selectedSubject lab equipment\n'
          'Procedure: Follow standard laboratory protocol.\n'
          'Precautions: Wear safety gear. Follow teacher instructions.';
      _steps = _guide.split('\n').where((l) => l.trim().isNotEmpty).toList();
    }

    setState(() {
      _isLoading = false;
      _labStarted = true;
    });
  }

  Future<void> _recordObservation() async {
    final text = _observationController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _observations.add({
        'text': text,
        'time': DateTime.now().toIso8601String(),
      });
    });
    _observationController.clear();
    _scrollToBottom();
  }

  Future<void> _finishLab() async {
    if (_observations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record at least one observation')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prompt =
        'Based on experiment "$_selectedExperiment" in $_selectedSubject:\n'
        'Observations recorded:\n${_observations.map((o) => '- ${o['text']}').join('\n')}\n\n'
        'Provide a scientific conclusion. Include:\n'
        '1. What was observed\n2. Scientific explanation\n'
        '3. Real-world application\nKeep it concise.';

    try {
      _conclusion = await AiAgentService.callAgent('custom', {'prompt': prompt});
    } catch (_) {
      _conclusion =
          'The experiment demonstrated key principles of $_selectedSubject. '
          'Further observation and analysis recommended.';
    }

    setState(() {
      _isLoading = false;
      _labComplete = true;
    });

    _saveSession();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetLab() {
    setState(() {
      _labStarted = false;
      _labComplete = false;
      _guide = '';
      _steps = [];
      _observations = [];
      _conclusion = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'AI Lab Simulator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_labStarted)
            IconButton(
              onPressed: _resetLab,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _labComplete
          ? _buildResultView()
          : _labStarted
              ? _buildLabView()
              : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science, size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Virtual Lab',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a subject and experiment to begin.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildSubjectSelector(),
          const SizedBox(height: 16),
          _buildExperimentSelector(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startLab,
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
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isLoading ? 'Preparing Lab...' : 'Start Lab',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastSessions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastSessions.length.clamp(0, 5), (i) {
              final s = _pastSessions[i];
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
                      child: const Icon(Icons.science,
                          color: Colors.deepPurpleAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['experiment'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${s['subject']} • ${(s['observations'] as List?)?.length ?? 0} observations',
                            style: TextStyle(
                              color: Colors.white.withAlpha(120),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return _buildChipSelector(
      'Subject',
      ['Chemistry', 'Physics', 'Biology'],
      _selectedSubject,
      (val) => setState(() {
        _selectedSubject = val!;
        _selectedExperiment = _experimentsBySubject[_selectedSubject]!.first;
      }),
    );
  }

  Widget _buildExperimentSelector() {
    final experiments = _experimentsBySubject[_selectedSubject]!;
    return _buildChipSelector(
      'Experiment',
      experiments,
      _selectedExperiment,
      (val) => setState(() => _selectedExperiment = val!),
    );
  }

  Widget _buildChipSelector(
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
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

  Widget _buildLabView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: Row(
            children: [
              Icon(Icons.science, color: Colors.deepPurpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedExperiment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_observations.length} obs',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Experiment Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ..._steps.map((step) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        step,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    )).toList().animate().fade(),
                const SizedBox(height: 20),
                const Text(
                  'Observations',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (_observations.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No observations recorded yet.',
                      style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ..._observations.map((obs) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.tealAccent.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.tealAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              obs['text'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList().animate().fade(),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: Colors.deepPurpleAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _observationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Record observation...',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                      filled: true,
                      fillColor: const Color(0xFF0F0F13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _recordObservation(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _recordObservation,
                  icon: const Icon(Icons.add_circle,
                      color: Colors.deepPurpleAccent),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _isLoading ? null : _finishLab,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Finish'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.emoji_events,
              size: 72, color: Colors.tealAccent.withAlpha(200)),
          const SizedBox(height: 16),
          const Text(
            'Lab Complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedExperiment,
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.tealAccent.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conclusion',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _conclusion,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.1),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recorded Observations',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ..._observations.map((obs) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle,
                              color: Colors.tealAccent, size: 8),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              obs['text'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ).animate().fade().slideY(begin: 0.1),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetLab,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'New Experiment',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
