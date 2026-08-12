import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/daily_quiz_service.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  final _quizService = DailyQuizService();
  final _gamification = GamificationService();
  late List<DailyQuizQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedAnswer;
  bool _showExplanation = false;
  int _timeLeft = 30;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _questions = _quizService.todayQuestions;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft > 0 && !_answered) {
        setState(() => _timeLeft--);
      } else if (_timeLeft == 0 && !_answered) {
        _handleAnswer(-1);
      }
    });
  }

  void _handleAnswer(int index) {
    _timer?.cancel();
    setState(() {
      _answered = true;
      _selectedAnswer = index;
      _showExplanation = true;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
    _quizService.recordAnswer(_score);
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedAnswer = null;
        _showExplanation = false;
        _timeLeft = 30;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      _gamification.recordQuizCompletion(
        _score,
        totalQuestions: _questions.length,
      );
      setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _completed ? _buildResults(context) : _buildQuiz(context);
  }

  Widget _buildQuiz(BuildContext ctx) {
    final t = ctx.tokens;
    final q = _questions[_currentIndex];

    return NexusScreen(
      title: 'Daily Quiz',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.md),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xxs,
              ),
              decoration: BoxDecoration(
                color: (_timeLeft <= 10 ? t.statusAbsent : t.primary)
                    .withValues(alpha: 0.2),
                borderRadius: AppRadius.brPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _timeLeft <= 10 ? t.statusAbsent : t.primary,
                  ),
                  const SizedBox(width: AppSpace.xxs),
                  Text(
                    '$_timeLeft s',
                    style: ctx.text.labelLarge?.copyWith(
                      color: _timeLeft <= 10 ? t.statusAbsent : t.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              children: [
                Text(
                  'Q${_currentIndex + 1}/${_questions.length}',
                  style: ctx.text.labelLarge?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    backgroundColor: t.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(t.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  'Score: $_score',
                  style: ctx.text.labelLarge?.copyWith(
                    color: t.statusPresent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _getSubjectColor(ctx, q.subject).withValues(alpha: 0.2),
              borderRadius: AppRadius.brSm,
            ),
            child: Text(
              q.subject,
              style: ctx.text.labelSmall?.copyWith(
                color: _getSubjectColor(ctx, q.subject),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.question,
                    style: ctx.text.headlineSmall?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  ...List.generate(4, (i) {
                    final isSelected = _selectedAnswer == i;
                    final isCorrectOption = i == q.correctIndex;
                    Color bgColor = t.surface;
                    Color borderColor = t.border;
                    Color textColor = t.ink;

                    if (_answered) {
                      if (isCorrectOption) {
                        bgColor = t.statusPresent.withValues(alpha: 0.15);
                        borderColor = t.statusPresent;
                        textColor = t.statusPresent;
                      } else if (isSelected && !isCorrectOption) {
                        bgColor = t.statusAbsent.withValues(alpha: 0.15);
                        borderColor = t.statusAbsent;
                        textColor = t.statusAbsent;
                      }
                    } else if (isSelected) {
                      bgColor = t.primaryTint;
                      borderColor = t.primary;
                    }

                    return GestureDetector(
                      onTap: _answered ? null : () => _handleAnswer(i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpace.sm),
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: AppRadius.brMd,
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCorrectOption && _answered
                                    ? t.statusPresent
                                    : t.surfaceAlt,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i),
                                  style: ctx.text.labelMedium?.copyWith(
                                    color: isCorrectOption && _answered
                                        ? t.onPrimary
                                        : t.inkMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                q.options[i],
                                style: ctx.text.bodyLarge?.copyWith(
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (_answered && isCorrectOption)
                              Icon(
                                Icons.check_circle,
                                color: t.statusPresent,
                              ),
                            if (_answered && isSelected && !isCorrectOption)
                              Icon(Icons.cancel, color: t.statusAbsent),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_showExplanation) ...[
                    const SizedBox(height: AppSpace.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      decoration: BoxDecoration(
                        color: t.primaryTint,
                        borderRadius: AppRadius.brMd,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: t.primary, size: 20),
                          const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: Text(
                              q.explanation,
                              style: ctx.text.bodySmall?.copyWith(
                                color: t.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_answered)
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: SizedBox(
                width: double.infinity,
                child: NexusButton(
                  label: _currentIndex < _questions.length - 1
                      ? 'Next Question →'
                      : 'See Results',
                  icon: Icons.arrow_forward,
                  onPressed: _nextQuestion,
                  fullWidth: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext ctx) {
    final t = ctx.tokens;
    final percentage = (_score / _questions.length * 100).round();
    String message;
    String emoji;
    if (percentage >= 90) {
      message = 'Outstanding! You\'re a genius!';
      emoji = '🏆';
    } else if (percentage >= 70) {
      message = 'Great job! Keep it up!';
      emoji = '🎉';
    } else if (percentage >= 50) {
      message = 'Good effort! Room to improve.';
      emoji = '👍';
    } else {
      message = 'Keep practicing! You\'ll get better.';
      emoji = '💪';
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: ctx.text.displaySmall),
              const SizedBox(height: AppSpace.md),
              Text(
                'Quiz Complete!',
                style: ctx.text.headlineMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                message,
                style: ctx.text.bodyMedium?.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: AppSpace.xl * 2),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.primaryTint,
                  border: Border.all(color: t.primary, width: 4),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_score/${_questions.length}',
                        style: ctx.text.displaySmall?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: ctx.typeExtras.bodyStrong.copyWith(color: t.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl * 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResultStat(
                    ctx,
                    'Correct',
                    '$_score',
                    t.statusPresent,
                  ),
                  _buildResultStat(
                    ctx,
                    'Wrong',
                    '${_questions.length - _score}',
                    t.statusAbsent,
                  ),
                  _buildResultStat(
                    ctx,
                    'XP Earned',
                    '+${_score * 20}',
                    t.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl * 2),
              SizedBox(
                width: double.infinity,
                child: NexusButton(
                  label: 'Done',
                  icon: Icons.check,
                  onPressed: () => Navigator.pop(context),
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultStat(
    BuildContext ctx,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: ctx.text.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: ctx.text.labelSmall?.copyWith(color: ctx.tokens.inkMuted),
        ),
      ],
    );
  }

  Color _getSubjectColor(BuildContext ctx, String subject) {
    final t = ctx.tokens;
    switch (subject) {
      case 'Physics':
        return t.primary;
      case 'Chemistry':
        return t.secondary;
      case 'Mathematics':
        return t.ink;
      case 'Biology':
        return t.inkMuted;
      default:
        return t.secondary;
    }
  }
}
