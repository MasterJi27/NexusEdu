import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_agent_service.dart';
import 'package:nexus_edu/core/services/local_history_store.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/ai_tool_scaffold.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

class MathWordSolverScreen extends StatefulWidget {
  const MathWordSolverScreen({super.key});

  @override
  State<MathWordSolverScreen> createState() => _MathWordSolverScreenState();
}

class _MathWordSolverScreenState extends State<MathWordSolverScreen> {
  final TextEditingController _problemController = TextEditingController();
  bool _isLoading = false;
  bool _solved = false;
  String? _error;

  String _given = '';
  String _toFind = '';
  String _formula = '';
  String _solution = '';
  String _answer = '';
  String _practiceProblems = '';
  List<Map<String, dynamic>> _pastSolutions = [];
  static const _historyStore = LocalHistoryStore('math_solutions');

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
    final solutions = await _historyStore.load();
    setState(() => _pastSolutions = solutions);
  }

  Future<void> _saveSolution() async {
    final updated = [
      ..._pastSolutions,
      {
        'problem': _problemController.text.trim(),
        'given': _given,
        'toFind': _toFind,
        'formula': _formula,
        'solution': _solution,
        'answer': _answer,
        'timestamp': DateTime.now().toIso8601String(),
      },
    ];
    if (updated.length > 20) updated.removeAt(0);
    await _historyStore.save(updated);
    _loadSolutions();
  }

  Future<void> _solveStepByStep() async {
    final problem = _problemController.text.trim();
    if (problem.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _solved = false;
    });

    try {
      final result = await AiAgentService.callAgent(
        'doubt_solver',
        {'question': problem, 'subject': 'Mathematics'},
      );
      _parseSolution(result);
      setState(() {
        _isLoading = false;
        _solved = true;
      });
      _saveSolution();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't solve this problem. Check your connection and try again.";
      });
    }
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
    final t = context.tokens;
    return AiToolScaffold(
      title: 'Math Word Problem Solver',
      subtitle:
          'Type or paste a math word problem. AI will break it down step by step.',
      actions: [
        if (_solved)
          IconButton(
            tooltip: 'Solve another',
            icon: Icon(Icons.refresh, color: t.primary),
            onPressed: _resetSolver,
          ),
      ],
      inputForm: NexusTextField(
        controller: _problemController,
        hint: 'e.g., A train travels 360 km in 4 hours. What is its speed?',
        maxLines: 6,
        minLines: 4,
      ),
      generateLabel: 'Solve Step-by-Step',
      isGenerating: _isLoading,
      onGenerate: _solveStepByStep,
      errorText: _error,
      onRetry: _solveStepByStep,
      resultBuilder: (ctx) =>
          _solved ? _buildSolutionView(ctx) : const SizedBox.shrink(),
      historyTitle: 'Past Solutions',
      history: List.generate(
        _pastSolutions.length.clamp(0, 5),
        (i) => _buildSavedItem(context, _pastSolutions[i]),
      ),
    );
  }

  Widget _buildSolutionView(BuildContext ctx) {
    final t = ctx.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NexusCard(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Text(
            _problemController.text.trim(),
            style: ctx.text.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: t.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _buildSolutionCard(ctx, 'Given', _given, Icons.info_outline, t.primary),
        _buildSolutionCard(ctx, 'To Find', _toFind, Icons.search, t.statusLate),
        _buildSolutionCard(ctx, 'Formula', _formula, Icons.functions, t.secondary),
        _buildSolutionCard(ctx, 'Solution', _solution, Icons.build, t.statusPresent),
        if (_answer.isNotEmpty) ...[
          NexusCard(
            background: t.statusPresent.withValues(alpha: 0.06),
            borderColor: t.statusPresent.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Answer',
                  style: ctx.text.labelLarge?.copyWith(color: t.statusPresent),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(_answer, style: ctx.text.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        if (_practiceProblems.isNotEmpty) ...[
          NexusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice Problems',
                  style: ctx.text.labelLarge?.copyWith(color: t.primary),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  _practiceProblems,
                  style: ctx.text.bodyMedium?.copyWith(
                    color: t.inkMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        const SizedBox(height: AppSpace.sm),
        NexusButton(
          label: 'Solve Another',
          icon: Icons.refresh,
          variant: NexusButtonVariant.secondary,
          onPressed: _resetSolver,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildSolutionCard(
    BuildContext ctx,
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    final t = ctx.tokens;
    if (content.isEmpty) return const SizedBox.shrink();
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpace.xs),
              Text(title, style: ctx.text.labelLarge?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            content,
            style: ctx.text.bodyMedium?.copyWith(color: t.inkMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedItem(BuildContext context, Map<String, dynamic> s) {
    final t = context.tokens;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.xs),
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calculate, color: t.secondary, size: 18),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (s['problem'] as String?) ?? '',
                  style: context.text.labelMedium?.copyWith(color: t.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  'Answer: ${s['answer'] ?? ''}',
                  style: context.text.bodySmall?.copyWith(color: t.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
