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

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  String _examType = 'JEE';
  String _selectedSubject = 'Physics';
  int _durationMinutes = 60;
  bool _isLoading = false;
  bool _testStarted = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  Set<int> _markedForReview = {};
  int _score = 0;
  int _timeLeft = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _results = [];
  String? _error;
  static const _historyStore = LocalHistoryStore('mock_test_results');

  final Map<String, List<String>> _subjectsByExam = {
    'JEE': ['Physics', 'Chemistry', 'Maths'],
    'NEET': ['Physics', 'Chemistry', 'Biology'],
    'CBSE Board': ['Physics', 'Chemistry', 'Biology', 'Maths', 'English'],
    'State Board': ['Physics', 'Chemistry', 'Biology', 'Maths'],
  };

  @override
  void initState() {
    super.initState();
    _selectedSubject = _subjectsByExam[_examType]!.first;
    _loadResults();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadResults() async {
    final results = await _historyStore.load();
    setState(() => _results = results);
  }

  Future<void> _saveResults() async {
    await _historyStore.save(_results);
  }

  Future<void> _startTest() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _questions = [];
    });

    final prompt = "Generate a mock $_examType test for $_selectedSubject. "
        "Duration: $_durationMinutes minutes. "
        "Return exactly 20 MCQs. Each object must have: "
        "\"question\" (string), \"options\" (array of 4 strings), "
        "\"correctIndex\" (int 0-3), \"explanation\" (string), "
        "\"topic\" (string). "
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
        _currentIndex = 0;
        _score = 0;
        _selectedAnswer = null;
        _answered = false;
        _markedForReview = {};
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Couldn't generate the test. Check your connection and try again.";
      });
    }
  }

  void _startTimer() {
    _timeLeft = _durationMinutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  void _autoSubmit() {
    _finishTest();
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentIndex]['correctIndex']) _score++;
    });
  }

  void _toggleMarkForReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
    _timer?.cancel();
    final percentage = (_score / _questions.length * 100).round();

    final result = {
      'exam': _examType,
      'subject': _selectedSubject,
      'score': _score,
      'total': _questions.length,
      'percentage': percentage,
      'duration': _durationMinutes,
      'markedReview': _markedForReview.length,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _results.insert(0, result);
    if (_results.length > 20) _results.removeLast();
    _saveResults();
    _showResultsDialog(result);
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    final pct = result['percentage'] as int;
    final timeTaken = _durationMinutes - (_timeLeft ~/ 60);

    final subjectScores = <String, Map<String, int>>{};
    for (final q in _questions) {
      final topic = q['topic'] ?? 'Unknown';
      subjectScores.putIfAbsent(topic, () => {'correct': 0, 'total': 0});
      subjectScores[topic]!['total'] = subjectScores[topic]!['total']! + 1;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        return AlertDialog(
              backgroundColor: t.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
              title: Column(
                children: [
                  Icon(
                    pct >= 70 ? Icons.emoji_events : Icons.assessment,
                    color: pct >= 70 ? t.secondaryFill : t.primary,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Test Complete!',
                    style: ctx.text.titleLarge?.copyWith(color: t.ink),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _resultRow(ctx, 'Score', '${result['score']}/${result['total']}'),
                    const SizedBox(height: AppSpace.xs),
                    _resultRow(ctx, 'Accuracy', '$pct%'),
                    const SizedBox(height: AppSpace.xs),
                    _resultRow(ctx, 'Time Taken', '$timeTaken min'),
                    const SizedBox(height: AppSpace.xs),
                    _resultRow(ctx, 'Marked for Review', '${result['markedReview']}'),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Topic-wise Breakdown',
                            style: ctx.text.labelMedium?.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          ...subjectScores.entries.take(6).map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpace.xxs),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.key,
                                        style: ctx.text.labelSmall?.copyWith(
                                          color: t.inkMuted,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${e.value['correct']}/${e.value['total']}',
                                      style: ctx.text.labelSmall?.copyWith(
                                        color: t.statusPresent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _testStarted = false;
                      _questions.clear();
                    });
                  },
                  child: Text(
                    'OK',
                    style: ctx.text.labelLarge?.copyWith(color: t.statusPresent),
                  ),
                ),
              ],
            );
      },
    );
  }

  Widget _resultRow(BuildContext context, String label, String value) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.text.bodyMedium?.copyWith(color: t.inkMuted)),
        Text(
          value,
          style: context.typeExtras.bodyStrong.copyWith(color: t.ink),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: _testStarted ? 'Mock Test - $_examType' : 'Mock Test',
      actions: [
        if (_testStarted)
          TextButton(
            onPressed: _finishTest,
            child: Text(
              'Submit',
              style: context.text.labelLarge?.copyWith(color: t.statusAbsent),
            ),
          ),
      ],
      body: _testStarted ? _buildTestView(context) : _buildSetupView(context),
    );
  }

  Widget _buildSetupView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExamTypeSelector(context),
          const SizedBox(height: AppSpace.md),
          _buildSubjectSelector(context),
          const SizedBox(height: AppSpace.md),
          _buildDurationSelector(context),
          const SizedBox(height: AppSpace.lg),
          NexusButton(
            label: _isLoading ? 'Preparing Test...' : 'Start Mock Test',
            icon: Icons.play_arrow,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _startTest,
            fullWidth: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            NexusBanner(
              message: _error!,
              kind: NexusBannerKind.error,
              actionLabel: 'Retry',
              onAction: _startTest,
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xl),
            const NexusSectionHeader(title: 'Past Results', spaceAbove: 0),
            ...List.generate(_results.length.clamp(0, 10), (i) {
              return _buildResultCard(context, _results[i]);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildExamTypeSelector(BuildContext context) {
    return _buildSelectorRow(
      context,
      'Exam Type',
      ['JEE', 'NEET', 'CBSE Board', 'State Board'],
      _examType,
      (val) => setState(() {
        _examType = val!;
        _selectedSubject = _subjectsByExam[_examType]!.first;
      }),
    );
  }

  Widget _buildSubjectSelector(BuildContext context) {
    return _buildSelectorRow(
      context,
      'Subject',
      _subjectsByExam[_examType]!,
      _selectedSubject,
      (val) => setState(() => _selectedSubject = val!),
    );
  }

  Widget _buildDurationSelector(BuildContext context) {
    return _buildSelectorRow(
      context,
      'Duration',
      ['60 min', '120 min', '180 min'],
      '$_durationMinutes min',
      (val) => setState(() {
        _durationMinutes = int.parse(val!.split(' ').first);
      }),
    );
  }

  Widget _buildSelectorRow(
    BuildContext context,
    String label,
    List<String> options,
    String selected,
    ValueChanged<String?> onChanged,
  ) {
    final t = context.tokens;
    return NexusCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: t.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: AppMotion.tap,
                  curve: AppMotion.standard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? t.primaryTint : t.surfaceAlt,
                    borderRadius: AppRadius.brSm,
                    border: Border.all(
                      color: isSelected ? t.primary : t.border,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: context.text.labelMedium?.copyWith(
                      color: isSelected ? t.primary : t.inkMuted,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTestView(BuildContext context) {
    final t = context.tokens;
    final q = _questions[_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final progress = (_currentIndex + 1) / _questions.length;
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final timerColor = _timeLeft > 300
        ? t.statusPresent
        : _timeLeft > 60
        ? t.statusLate
        : t.statusAbsent;
    final isMarked = _markedForReview.contains(_currentIndex);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(color: t.surface),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Q${_currentIndex + 1}/${_questions.length}',
                    style: context.text.titleMedium?.copyWith(
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
                      color: timerColor.withValues(alpha: 0.10),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: timerColor, size: 18),
                        const SizedBox(width: AppSpace.xxs),
                        Text(
                          '$minutes:${seconds.toString().padLeft(2, '0')}',
                          style: context.text.labelMedium?.copyWith(
                            color: timerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Score: $_score',
                    style: context.text.labelMedium?.copyWith(
                      color: t.statusPresent,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q['question'] ?? '',
                        style: context.text.titleMedium?.copyWith(
                          height: 1.4,
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleMarkForReview,
                      icon: Icon(
                        isMarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isMarked ? t.secondary : t.inkFaint,
                      ),
                      tooltip: 'Mark for Review',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                ...List.generate(options.length, (i) {
                  final isCorrect = i == q['correctIndex'];
                  final isSelected = _selectedAnswer == i;
                  Color bgColor = t.surface;
                  Color borderColor = t.border;
                  if (_answered) {
                    if (isCorrect) {
                      bgColor = t.statusPresent.withValues(alpha: 0.12);
                      borderColor = t.statusPresent;
                    } else if (isSelected && !isCorrect) {
                      bgColor = t.statusAbsent.withValues(alpha: 0.12);
                      borderColor = t.statusAbsent;
                    }
                  }
                  return GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              color: isSelected ? t.primaryTint : t.surfaceAlt,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: context.text.labelMedium?.copyWith(
                                  color: isSelected ? t.primary : t.inkMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              options[i],
                              style: context.text.bodyMedium?.copyWith(
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
                      borderRadius: AppRadius.brSm,
                      border: Border.all(color: t.primaryTintBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb, color: t.secondary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q['explanation'] ?? '',
                            style: context.text.bodySmall?.copyWith(
                              color: t.ink,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  NexusButton(
                    label: _currentIndex < _questions.length - 1
                        ? 'Next Question'
                        : 'Submit Test',
                    onPressed: _nextQuestion,
                    fullWidth: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildQuestionNavigator(context),
      ],
    );
  }

  Widget _buildQuestionNavigator(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
      decoration: BoxDecoration(color: t.surface),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final isCurrent = index == _currentIndex;
          final isMarked = _markedForReview.contains(index);
          final isAnswered =
              index < _currentIndex || (index == _currentIndex && _answered);
          Color color;
          if (isCurrent) {
            color = t.primary;
          } else if (isMarked) {
            color = t.secondary;
          } else if (isAnswered) {
            color = t.statusPresent;
          } else {
            color = t.inkFaint;
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _currentIndex = index;
                _selectedAnswer = null;
                _answered = false;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: AppRadius.brSm,
                border: Border.all(
                  color: color,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: context.text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, Map<String, dynamic> r) {
    final t = context.tokens;
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
                  style: context.text.labelLarge?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: ${r['score']}/${r['total']} (${r['percentage']}%) • ${r['duration']}min',
                  style: context.text.labelSmall?.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            '${r['percentage']}%',
            style: context.typeExtras.bodyStrong.copyWith(
              color: (r['percentage'] as int) >= 70
                  ? t.statusPresent
                  : (r['percentage'] as int) >= 50
                  ? t.secondary
                  : t.statusAbsent,
            ),
          ),
        ],
      ),
    );
  }
}
