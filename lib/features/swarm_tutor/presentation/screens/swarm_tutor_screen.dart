import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/ai_service.dart';

const _agentStrategies = [
  {'name': 'Visual', 'persona': 'Visual Artist', 'desc': 'Diagrams, colors, mental images', 'icon': Icons.image},
  {'name': 'Socratic', 'persona': 'Socrates', 'desc': 'Questions that lead to answers', 'icon': Icons.psychology},
  {'name': 'Gamified', 'persona': 'Game Master', 'desc': 'Points, challenges, levels', 'icon': Icons.sports_esports},
  {'name': 'Story-Based', 'persona': 'Storyteller', 'desc': 'Narratives & analogies', 'icon': Icons.auto_stories},
  {'name': 'Drill-Based', 'persona': 'Drill Sergeant', 'desc': 'Repetition & recall pressure', 'icon': Icons.fitness_center},
  {'name': 'Socratic', 'persona': 'Zen Master', 'desc': 'Minimalist, meditative explanations', 'icon': Icons.self_improvement},
  {'name': 'Analogy', 'persona': 'Metaphor Maker', 'desc': 'Real-world comparisons', 'icon': Icons.compare_arrows},
  {'name': 'Debugger', 'persona': 'Bug Hunter', 'desc': 'Teach via common mistakes', 'icon': Icons.bug_report},
];

class SwarmTutorScreen extends StatefulWidget {
  const SwarmTutorScreen({super.key});

  @override
  State<SwarmTutorScreen> createState() => _SwarmTutorScreenState();
}

class _SwarmTutorScreenState extends State<SwarmTutorScreen> {
  final _conceptCtrl = TextEditingController();
  bool _isRunning = false;
  int _currentAgentIndex = 0;
  String _selectedAnswer = '';
  int _correctCount = 0;
  int _totalAnswered = 0;

  List<Map<String, dynamic>> get _agents => AppSettings.instance.swarmAgentScores;
  List<Map<String, String>> _results = [];

  @override
  void initState() {
    super.initState();
    if (_agents.isEmpty) _initDefaultAgents();
  }

  Future<void> _initDefaultAgents() async {
    final defaults = _agentStrategies.asMap().entries.map((e) => {
      'id': e.key,
      'strategy': e.value['name'],
      'persona': e.value['persona'],
      'desc': e.value['desc'],
      'score': 50.0,
      'lessonsDelivered': 0,
      'generation': 0,
    }).toList();
    await AppSettings.instance.saveSwarmAgentScores(defaults);
  }

  Future<void> _runSwarm() async {
    final concept = _conceptCtrl.text.trim();
    if (concept.isEmpty) return;

    setState(() {
      _isRunning = true;
      _currentAgentIndex = 0;
      _results = [];
      _correctCount = 0;
      _totalAnswered = 0;
    });

    for (int i = 0; i < _agents.length; i++) {
      if (!mounted) return;
      setState(() => _currentAgentIndex = i);

      final agent = _agents[i];
      final result = await AiService.swarmTeach(
        concept,
        agent['strategy'] as String,
        agent['persona'] as String,
      );
      if (!mounted) return;
      _results.add(result);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() => _isRunning = false);
  }

  void _submitAnswer(String answer, int agentIndex) {
    final agent = _agents[agentIndex];
    final quizText = _results[agentIndex]['quiz'] ?? '';
    final correctLetter = _extractAnswer(quizText);
    final isCorrect = answer == correctLetter;

    setState(() {
      _selectedAnswer = answer;
      _totalAnswered++;
      if (isCorrect) _correctCount++;
    });

    agent['score'] = ((agent['score'] as double) + (isCorrect ? 5.0 : -3.0))
        .clamp(0, 100);
    agent['lessonsDelivered'] = (agent['lessonsDelivered'] as int) + 1;
    AppSettings.instance.saveSwarmAgentScores(_agents);
  }

  String _extractAnswer(String quiz) {
    final match = RegExp(r'Answer:\s*([A-D])', caseSensitive: false).firstMatch(quiz);
    return match?.group(1)?.toUpperCase() ?? '';
  }

  void _evolveAgents() {
    final sorted = List<Map<String, dynamic>>.from(_agents)
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    final topHalf = sorted.take(sorted.length ~/ 2).toList();
    final evolved = <Map<String, dynamic>>[];

    for (int i = 0; i < _agents.length; i++) {
      final parent = topHalf[i % topHalf.length];
      final child = Map<String, dynamic>.from(parent);
      child['generation'] = (parent['generation'] as int) + 1;
      child['score'] = 50.0;
      child['lessonsDelivered'] = 0;
      evolved.add(child);
    }

    AppSettings.instance.saveSwarmAgentScores(evolved);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Agents evolved to generation ${evolved.first['generation']}')),
    );
  }

  @override
  void dispose() {
    _conceptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swarm AGI Tutor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: _evolveAgents,
            tooltip: 'Evolve Agents (Darwinian selection)',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.withAlpha(60)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.groups_3, color: Colors.deepPurpleAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text('10,000 Agents • Darwinian Learning',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_agents.length} active agents | Top score: ${_agents.isEmpty ? 0 : (_agents.map((a) => a['score'] as double).reduce((a, b) => a > b ? a : b)).toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _conceptCtrl,
            decoration: InputDecoration(
              hintText: 'Enter a concept to learn...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              suffixIcon: _isRunning
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.rocket_launch),
                      onPressed: _runSwarm,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_totalAnswered > 0)
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Correct: $_correctCount/$_totalAnswered',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${(_correctCount / _totalAnswered * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _correctCount / _totalAnswered > 0.6
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ..._agents.asMap().entries.map((entry) {
            final idx = entry.key;
            final agent = entry.value;
            final isTeaching = _isRunning && idx == _currentAgentIndex;
            final hasResult = idx < _results.length;

            return Card(
              color: isTeaching ? Colors.deepPurple.withAlpha(40) : const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _agentStrategies.firstWhere(
                            (s) => s['name'] == agent['strategy'],
                            orElse: () => _agentStrategies[0],
                          )['icon'] as IconData,
                          size: 18,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(agent['persona'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (isTeaching)
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (agent['score'] as double) > 70
                                ? Colors.green.withAlpha(40)
                                : (agent['score'] as double) > 40
                                    ? Colors.orange.withAlpha(40)
                                    : Colors.red.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(agent['score'] as double).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: (agent['score'] as double) > 70
                                  ? Colors.greenAccent
                                  : (agent['score'] as double) > 40
                                      ? Colors.orangeAccent
                                      : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasResult && _results[idx]['lesson'] != null) ...[
                      const SizedBox(height: 8),
                      Text(_results[idx]['lesson']!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(_results[idx]['quiz'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      if (_results[idx]['quiz'] != null && _results[idx]['quiz']!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['A', 'B', 'C', 'D'].map((letter) {
                            final isSelected = _selectedAnswer == letter;
                            return ElevatedButton(
                              onPressed: isSelected ? null : () => _submitAnswer(letter, idx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? Colors.deepPurpleAccent
                                    : const Color(0xFF2A2A2A),
                              ),
                              child: Text(letter),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
