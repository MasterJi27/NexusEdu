import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/local_history_store.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';

class JeeNeetTrainerScreen extends StatefulWidget {
  const JeeNeetTrainerScreen({super.key});

  @override
  State<JeeNeetTrainerScreen> createState() => _JeeNeetTrainerScreenState();
}

class _JeeNeetTrainerScreenState extends State<JeeNeetTrainerScreen>
    with SingleTickerProviderStateMixin {
  String _examType = 'JEE Main';
  String _selectedSubject = 'Physics';
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _isLoading = false;
  bool _testStarted = false;
  int _timeLeft = 60;
  Timer? _timer;
  List<Map<String, dynamic>> _results = [];
  String? _error;
  static const _historyStore = LocalHistoryStore('jee_neet_results');

  late TabController _tabController;

  final Map<String, List<String>> _subjectsByExam = {
    'JEE Main': ['Physics', 'Chemistry', 'Maths'],
    'JEE Advanced': ['Physics', 'Chemistry', 'Maths'],
    'NEET': ['Physics', 'Chemistry', 'Biology'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _subjectsByExam[_examType]!.length, vsync: this);
    _loadResults();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final results = await _historyStore.load();
    setState(() => _results = results);
  }

  Future<void> _saveResults() async {
    await _historyStore.save(_results);
  }

  void _startTimer() {
    _timeLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        if (_selectedAnswer == null) _nextQuestion();
      }
    });
  }

  Future<void> _startPractice() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _questions = [];
      _currentIndex = 0;
      _score = 0;
      _testStarted = false;
    });

    final prompt = "Generate exactly 10 MCQs for $_examType $_selectedSubject exam. "
        "Each question must have 4 options (A, B, C, D) and one correct answer. "
        "Return a JSON array. Each object must have: "
        "\"question\" (string), \"options\" (array of 4 strings), "
        "\"correctIndex\" (int 0-3), \"explanation\" (string). "
        "No markdown, no code fences. Raw JSON only.";

    try {
      final result = await AiService.generateStructured(prompt);
      if (!mounted) return;

      final List<dynamic> parsed = json.decode(result);
      setState(() {
        _questions = parsed
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoading = false;
        _testStarted = true;
        _answered = false;
        _selectedAnswer = null;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't generate practice questions. Check your connection and try again.";
      });
    }
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    _timer?.cancel();
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentIndex]['correctIndex']) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _timer?.cancel();
    final result = {
      'exam': _examType,
      'subject': _selectedSubject,
      'score': _score,
      'total': _questions.length,
      'percentage': (_score / _questions.length * 100).round(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    _results.insert(0, result);
    if (_results.length > 30) _results.removeLast();
    _saveResults();
    _showResultsDialog();
  }

  void _showResultsDialog() {
    final pct = (_score / _questions.length * 100).round();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final tctx = dialogCtx;
        final t = tctx.tokens;
        return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
              title: Column(
                children: [
                  Icon(
                    pct >= 70 ? Icons.emoji_events : Icons.trending_up,
                    color: pct >= 70 ? t.statusLate : t.primary,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Practice Complete!',
                    style: tctx.text.titleMedium?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildResultRow(tctx, 'Score', '$_score / ${_questions.length}'),
                  const SizedBox(height: AppSpace.xs),
                  _buildResultRow(tctx, 'Accuracy', '$pct%'),
                  const SizedBox(height: AppSpace.xs),
                  _buildResultRow(tctx, 'Exam', _examType),
                  const SizedBox(height: AppSpace.xs),
                  _buildResultRow(tctx, 'Subject', _selectedSubject),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    setState(() => _testStarted = false);
                  },
                  child: Text(
                    'OK',
                    style: tctx.text.labelLarge?.copyWith(color: t.secondary),
                  ),
                ),
              ],
            );
      },
    );
  }

  Widget _buildResultRow(BuildContext ctx, String label, String value) {
    final t = ctx.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: ctx.text.bodyMedium?.copyWith(color: t.inkMuted)),
        Text(
          value,
          style: ctx.text.bodyMedium?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'JEE/NEET Trainer',
      body: _testStarted && _questions.isNotEmpty
          ? _buildQuizView(context)
          : _buildSetupView(context),
    );
  }

  Widget _buildSetupView(BuildContext ctx) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExamTypeSelector(ctx),
          const SizedBox(height: AppSpace.md),
          _buildSubjectTabs(ctx),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            width: double.infinity,
            child: NexusButton(
              label: _isLoading ? 'Generating...' : 'Start Practice',
              icon: Icons.play_arrow,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _startPractice,
              fullWidth: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            NexusBanner(
              message: _error!,
              kind: NexusBannerKind.error,
              actionLabel: 'Retry',
              onAction: _startPractice,
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          if (_results.isNotEmpty) ...[
            const NexusSectionHeader(title: 'Recent Results', spaceAbove: 0),
            const SizedBox(height: AppSpace.sm),
            ...List.generate(_results.length.clamp(0, 10), (i) {
              final r = _results[i];
              return _buildResultCard(ctx, r);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildExamTypeSelector(BuildContext ctx) {
    final t = ctx.tokens;
    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exam Type',
            style: ctx.text.labelSmall?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: ['JEE Main', 'JEE Advanced', 'NEET'].map((type) {
              final isSelected = _examType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    setState(() {
                      _examType = type;
                      // P1 verified: TabController reassign disposes old correctly with mounted guard.
                      final old = _tabController;
                      _tabController = TabController(
                          length: _subjectsByExam[type]!.length,
                          vsync: this);
                      old.dispose();
                      _selectedSubject = _subjectsByExam[type]!.first;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                    decoration: BoxDecoration(
                      color: isSelected ? t.primaryTint : t.surfaceAlt,
                      borderRadius: AppRadius.brMd,
                      border: Border.all(
                        color: isSelected ? t.primaryTintBorder : t.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        type,
                        style: ctx.text.labelSmall?.copyWith(
                          color: isSelected ? t.primary : t.inkMuted,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildSubjectTabs(BuildContext ctx) {
    final t = ctx.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: _subjectsByExam[_examType]!.map((subject) {
          final isSelected = _selectedSubject == subject;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSubject = subject),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? t.primaryTint
                      : Colors.transparent,
                  borderRadius: AppRadius.brSm,
                ),
                child: Center(
                  child: Text(
                    subject,
                    style: ctx.text.labelSmall?.copyWith(
                      color: isSelected ? t.primary : t.inkMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuizView(BuildContext ctx) {
    final t = ctx.tokens;
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final progress = (_currentIndex + 1) / _questions.length;
    final timerColor = _timeLeft > 30
        ? t.statusPresent
        : _timeLeft > 10
            ? t.statusLate
            : t.statusAbsent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          color: t.surface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Q${_currentIndex + 1}/${_questions.length}',
                    style: ctx.text.titleMedium?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.2),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: timerColor, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$_timeLeft s',
                          style: ctx.text.labelLarge?.copyWith(
                            color: timerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Score: $_score',
                    style: ctx.text.titleMedium?.copyWith(
                      color: t.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: t.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(t.primary),
                borderRadius: AppRadius.brSm,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q['question'] ?? '',
                  style: ctx.text.titleMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                ...List.generate(options.length, (i) {
                  final isCorrect = i == q['correctIndex'];
                  final isSelected = _selectedAnswer == i;
                  Color bgColor = t.surface;
                  Color borderColor = t.border;
                  if (_answered) {
                    if (isCorrect) {
                      bgColor = t.statusPresent.withValues(alpha: 0.15);
                      borderColor = t.statusPresent;
                    } else if (isSelected && !isCorrect) {
                      bgColor = t.statusAbsent.withValues(alpha: 0.15);
                      borderColor = t.statusAbsent;
                    }
                  }
                  return GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpace.sm),
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: AppRadius.brMd,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? t.primaryTint
                                  : t.surfaceAlt,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: ctx.text.labelMedium?.copyWith(
                                  color: isSelected
                                      ? t.primary
                                      : t.inkMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              options[i],
                              style: ctx.text.bodyMedium?.copyWith(
                                color: t.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_answered) ...[
                  const SizedBox(height: AppSpace.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: t.primaryTint,
                      borderRadius: AppRadius.brMd,
                      border: Border.all(color: t.primaryTintBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb,
                            color: t.statusLate, size: 20),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            q['explanation'] ?? '',
                            style: ctx.text.bodyMedium?.copyWith(
                              color: t.ink,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  SizedBox(
                    width: double.infinity,
                    child: NexusButton(
                      label: _currentIndex < _questions.length - 1
                          ? 'Next Question'
                          : 'Finish',
                      icon: _currentIndex < _questions.length - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                      onPressed: _nextQuestion,
                      fullWidth: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(BuildContext ctx, Map<String, dynamic> r) {
    final t = ctx.tokens;
    final pct = r['percentage'] as int;
    return NexusCard(
      margin: const EdgeInsets.only(bottom: AppSpace.xs),
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: t.primaryTint,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Icons.quiz, color: t.primary, size: 18),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['exam']} - ${r['subject']}',
                  style: ctx.text.labelMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']}/${r['total']} (${r['percentage']}%)',
                  style: ctx.text.labelSmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            '${r['percentage']}%',
            style: ctx.text.titleMedium?.copyWith(
              color: pct >= 70 ? t.statusPresent : t.statusLate,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
