import 'package:flutter/material.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/ai_tools_service.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_text_field.dart';

enum _Phase { setup, playing, results }

/// AI quiz generator: pick a class, subject and topic and the backend drafts
/// an exam-style MCQ set on the spot.
class QuizGeneratorScreen extends StatefulWidget {
  const QuizGeneratorScreen({super.key});

  @override
  State<QuizGeneratorScreen> createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  final AiToolsService _ai = AiToolsService();
  final _gamification = GamificationService();
  final TextEditingController _topicController = TextEditingController();

  _Phase _phase = _Phase.setup;
  bool _generating = false;
  String? _error;

  String? _grade;
  String _subject = 'All subjects';
  int _count = 5;
  double _sliderValue = 5;

  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final grade = await LearnerProfileService.getSelectedClass();
    if (!mounted) return;
    setState(() => _grade = grade);
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  List<String> get _subjects {
    final subjects = LearningCatalog.subjectsFor(_grade).map((s) => s.name).toList();
    return ['All subjects', ...subjects];
  }

  Future<void> _generate() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
      _count = _sliderValue.round();
    });

    final questions = await _ai.generateQuiz(
      topic: topic,
      subject: _subject,
      gradeLevel: _grade,
      count: _count,
    );

    if (!mounted) return;
    if (questions == null || questions.isEmpty) {
      setState(() {
        _generating = false;
        _error =
            'Could not generate the quiz. Check your connection and your daily AI limit, then try again.';
      });
      return;
    }

    setState(() {
      _generating = false;
      _questions = questions;
      _phase = _Phase.playing;
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedAnswer = null;
    });
  }

  void _handleAnswer(int index) {
    setState(() {
      _answered = true;
      _selectedAnswer = index;
      if (index == _questions[_currentIndex]['correctIndex']) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedAnswer = null;
      });
    } else {
      _gamification.recordQuizCompletion(_score, totalQuestions: _questions.length);
      setState(() => _phase = _Phase.results);
    }
  }

  void _reset() {
    setState(() {
      _phase = _Phase.setup;
      _questions = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(
      title: 'Quiz generator',
      body: switch (_phase) {
        _Phase.setup => _buildSetup(context),
        _Phase.playing => _buildQuiz(context),
        _Phase.results => _buildResults(context),
      },
    );
  }

  // ---------------------------------------------------------------- setup

  Widget _buildSetup(BuildContext ctx) {
    final t = ctx.tokens;
    return SingleChildScrollView(
      padding: AppSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NexusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Class', style: ctx.text.labelMedium?.copyWith(color: t.inkMuted)),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: LearningCatalog.classes.map((g) {
                    final selected = _grade == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      labelStyle: ctx.text.labelSmall?.copyWith(
                        color: selected ? t.onPrimary : t.ink,
                      ),
                      selectedColor: t.primary,
                      backgroundColor: t.surfaceAlt,
                      side: BorderSide(color: selected ? t.primary : t.border),
                      onSelected: (_) => setState(() {
                        _grade = g;
                        _subject = 'All subjects';
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Subject', style: ctx.text.labelMedium?.copyWith(color: t.inkMuted)),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: _subjects.map((s) {
                    final selected = _subject == s;
                    return ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      labelStyle: ctx.text.labelSmall?.copyWith(
                        color: selected ? t.onPrimary : t.ink,
                      ),
                      selectedColor: t.primary,
                      backgroundColor: t.surfaceAlt,
                      side: BorderSide(color: selected ? t.primary : t.border),
                      onSelected: (_) => setState(() => _subject = s),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          NexusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Topic', style: ctx.text.labelMedium?.copyWith(color: t.inkMuted)),
                const SizedBox(height: AppSpace.sm),
                NexusTextField(
                  controller: _topicController,
                  hint: 'e.g. Photosynthesis, Quadratic equations…',
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Text('Questions', style: ctx.text.labelMedium?.copyWith(color: t.inkMuted)),
                    const Spacer(),
                    Text('$_count', style: ctx.typeExtras.figure.copyWith(color: t.primary)),
                  ],
                ),
                Slider(
                  value: _sliderValue,
                  min: 3,
                  max: 15,
                  divisions: 12,
                  label: '$_count',
                  onChanged: (v) => setState(() {
                    _sliderValue = v;
                    _count = v.round();
                  }),
                ),
                const SizedBox(height: AppSpace.sm),
                NexusButton(
                  label: 'Generate quiz',
                  icon: Icons.auto_awesome_outlined,
                  isLoading: _generating,
                  onPressed: _topicController.text.trim().isEmpty || _generating
                      ? null
                      : _generate,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            NexusCard(
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: t.statusAbsent),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(_error!, style: ctx.text.bodySmall?.copyWith(color: t.ink)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- playing

  Widget _buildQuiz(BuildContext ctx) {
    final t = ctx.tokens;
    final q = _questions[_currentIndex];
    final options = (q['options'] as List).cast<String>();
    final correctIndex = (q['correctIndex'] as num).toInt();

    return SingleChildScrollView(
      padding: AppSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Q${_currentIndex + 1}/${_questions.length}',
                style: ctx.text.labelLarge?.copyWith(color: t.primary),
              ),
              const Spacer(),
              Text('Score: $_score', style: ctx.text.labelMedium?.copyWith(color: t.inkMuted)),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: AppRadius.brSm,
            child: LinearProgressIndicator(
              value: (_currentIndex + (_answered ? 1 : 0)) / _questions.length,
              minHeight: 6,
              color: t.primary,
              backgroundColor: t.surfaceAlt,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(q['question'].toString(), style: ctx.text.headlineSmall?.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.lg),
          ...List.generate(options.length, (i) {
            final isCorrect = _answered && i == correctIndex;
            final isWrongPick = _answered && i == _selectedAnswer && i != correctIndex;
            return GestureDetector(
              onTap: _answered ? null : () => _handleAnswer(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpace.sm),
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? t.statusPresent.withValues(alpha: 0.15)
                      : isWrongPick
                          ? t.statusAbsent.withValues(alpha: 0.15)
                          : t.surface,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: isCorrect
                        ? t.statusPresent
                        : isWrongPick
                            ? t.statusAbsent
                            : t.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: ctx.text.labelMedium?.copyWith(color: t.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(options[i], style: ctx.text.bodyMedium?.copyWith(color: t.ink)),
                    ),
                    if (isCorrect) Icon(Icons.check_circle, color: t.statusPresent),
                    if (isWrongPick) Icon(Icons.cancel, color: t.statusAbsent),
                  ],
                ),
              ),
            );
          }),
          if (_answered) ...[
            Container(
              margin: const EdgeInsets.only(top: AppSpace.xs),
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: t.primaryTint,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: t.primary, size: 20),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      q['explanation']?.toString() ?? 'No explanation available.',
                      style: ctx.text.bodySmall?.copyWith(color: t.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            NexusButton(
              label: _currentIndex == _questions.length - 1 ? 'Finish quiz' : 'Next question',
              icon: Icons.arrow_forward,
              onPressed: _nextQuestion,
              fullWidth: true,
            ),
          ],
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- results

  Widget _buildResults(BuildContext ctx) {
    final t = ctx.tokens;
    final pct = _questions.isEmpty
        ? 0
        : ((_score / _questions.length) * 100).round();
    return SingleChildScrollView(
      padding: AppSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.lg),
          Center(
            child: Container(
              width: 140,
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.primaryTint,
                border: Border.all(color: t.primary, width: 4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_score/${_questions.length}',
                    style: ctx.typeExtras.figureLg.copyWith(color: t.ink),
                  ),
                  Text('$pct%', style: ctx.text.labelMedium?.copyWith(color: t.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            pct >= 80
                ? 'Excellent work!'
                : pct >= 50
                    ? 'Good effort!'
                    : 'Keep practising!',
            textAlign: TextAlign.center,
            style: ctx.text.headlineSmall?.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'XP earned: +${_score * 20}',
            textAlign: TextAlign.center,
            style: ctx.text.bodyMedium?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.xl),
          NexusButton(
            label: 'Another quiz',
            icon: Icons.refresh,
            variant: NexusButtonVariant.secondary,
            onPressed: _reset,
            fullWidth: true,
          ),
          const SizedBox(height: AppSpace.sm),
          NexusButton(
            label: 'Done',
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(),
            fullWidth: true,
          ),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }
}
