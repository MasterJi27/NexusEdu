import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MathWordSolverScreen extends StatefulWidget {
  const MathWordSolverScreen({super.key});

  @override
  State<MathWordSolverScreen> createState() => _MathWordSolverScreenState();
}

class _MathWordSolverScreenState extends State<MathWordSolverScreen> {
  final TextEditingController _problemController = TextEditingController();
  bool _isLoading = false;
  bool _solved = false;

  String _given = '';
  String _toFind = '';
  String _formula = '';
  String _solution = '';
  String _answer = '';
  String _practiceProblems = '';
  List<Map<String, dynamic>> _pastSolutions = [];

  @override
  void initState() {
    super.initState();
    _loadSolutions();
  }

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _loadSolutions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('math_solutions') ?? [];
    setState(() {
      _pastSolutions = saved
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveSolution() async {
    final prefs = await SharedPreferences.getInstance();
    final solutions = prefs.getStringList('math_solutions') ?? [];
    solutions.add(json.encode({
      'problem': _problemController.text.trim(),
      'given': _given,
      'toFind': _toFind,
      'formula': _formula,
      'solution': _solution,
      'answer': _answer,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    if (solutions.length > 20) solutions.removeAt(0);
    await prefs.setStringList('math_solutions', solutions);
    _loadSolutions();
  }

  Future<void> _solveStepByStep() async {
    final problem = _problemController.text.trim();
    if (problem.isEmpty) return;

    setState(() {
      _isLoading = true;
      _solved = false;
    });

    try {
      final result = await AiAgentService.callAgent(
        'doubt_solver',
        {'question': problem, 'subject': 'Mathematics'},
      );
      _parseSolution(result);
    } catch (_) {
      _given = 'Problem data';
      _toFind = 'The answer';
      _formula = 'Standard mathematical formulas';
      _solution = 'Apply the appropriate formula and solve step by step.';
      _answer = 'Solution unavailable offline.';
      _practiceProblems = '1. Similar problem 1\n2. Similar problem 2';
    }

    setState(() {
      _isLoading = false;
      _solved = true;
    });

    _saveSolution();
  }

  void _parseSolution(String response) {
    _given = _extractSection(response, 'GIVEN:');
    _toFind = _extractSection(response, 'TO FIND:');
    _formula = _extractSection(response, 'FORMULA:');
    _solution = _extractSection(response, 'SOLUTION:');
    _answer = _extractSection(response, 'ANSWER:');
    _practiceProblems = _extractSection(response, 'PRACTICE:');

    if (_given.isEmpty && _toFind.isEmpty) {
      _given = response;
      _toFind = '';
      _formula = '';
      _solution = '';
      _answer = '';
      _practiceProblems = '';
    }
  }

  String _extractSection(String text, String header) {
    final idx = text.indexOf(header);
    if (idx == -1) return '';
    final start = idx + header.length;
    final sections = ['GIVEN:', 'TO FIND:', 'FORMULA:', 'SOLUTION:', 'ANSWER:', 'PRACTICE:'];
    int end = text.length;
    for (final s in sections) {
      if (s == header) continue;
      final sIdx = text.indexOf(s, start);
      if (sIdx != -1 && sIdx < end) end = sIdx;
    }
    return text.substring(start, end).trim();
  }

  void _resetSolver() {
    setState(() {
      _solved = false;
      _given = '';
      _toFind = '';
      _formula = '';
      _solution = '';
      _answer = '';
      _practiceProblems = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text(
          'Math Word Problem Solver',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_solved)
            IconButton(
              onPressed: _resetSolver,
              icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
            ),
        ],
      ),
      body: _solved ? _buildSolutionView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calculate,
              size: 64, color: Colors.deepPurpleAccent.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'Solve Word Problems',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type or paste a math word problem. AI will break it down step by step.',
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _problemController,
              style: const TextStyle(color: Colors.white),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'e.g., A train travels 360 km in 4 hours. What is its speed?',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading || _problemController.text.trim().isEmpty
                  ? null
                  : _solveStepByStep,
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
                  : const Icon(Icons.psychology),
              label: Text(
                _isLoading ? 'Solving...' : 'Solve Step-by-Step',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_pastSolutions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Past Solutions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_pastSolutions.length.clamp(0, 5), (i) {
              final s = _pastSolutions[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (s['problem'] as String?) ?? '',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Answer: ${s['answer'] ?? ''}',
                      style: TextStyle(
                        color: Colors.tealAccent.withAlpha(200),
                        fontSize: 12,
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

  Widget _buildSolutionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(40)),
            ),
            child: Text(
              _problemController.text.trim(),
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSolutionCard('Given', _given, Icons.info_outline, Colors.blueAccent),
          _buildSolutionCard('To Find', _toFind, Icons.search, Colors.amberAccent),
          _buildSolutionCard('Formula', _formula, Icons.functions, Colors.deepPurpleAccent),
          _buildSolutionCard('Solution', _solution, Icons.build, Colors.tealAccent),
          if (_answer.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Answer',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _answer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ).animate().fade().scale(),
          if (_practiceProblems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Practice Problems',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _practiceProblems,
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ).animate().fade(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetSolver,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Solve Another',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard(
      String title, String content, IconData icon, Color color) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }
}
