import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/repositories/ai_repository.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Generic quiz state machine — replaces duplicated timer/_handleAnswer/_finishTest
/// in `mock_test_screen.dart:23`, `daily_quiz_screen.dart:16`, `quiz_generator_screen.dart:23`.
class QuizQuestion {
  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.subject,
  });
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String? subject;

  factory QuizQuestion.fromMap(Map<String, dynamic> m) => QuizQuestion(
        question: m['question']?.toString() ?? '',
        options: (m['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? (m['correct'] as num?)?.toInt() ?? 0,
        explanation: m['explanation']?.toString(),
        subject: m['subject']?.toString(),
      );
}

enum QuizPhase { setup, loading, playing, finished }

class QuizSessionState {
  const QuizSessionState({
    this.phase = QuizPhase.setup,
    this.questions = const [],
    this.currentIndex = 0,
    this.score = 0,
    this.selectedAnswer,
    this.timeLeft = 0,
    this.markedForReview = const {},
    this.error,
  });

  final QuizPhase phase;
  final List<QuizQuestion> questions;
  final int currentIndex;
  final int score;
  final int? selectedAnswer;
  final int timeLeft;
  final Set<int> markedForReview;
  final String? error;

  QuizQuestion? get currentQuestion =>
      questions.isEmpty || currentIndex >= questions.length ? null : questions[currentIndex];

  bool get isFinished => phase == QuizPhase.finished;
  bool get isLast => currentIndex == questions.length - 1;

  QuizSessionState copyWith({
    QuizPhase? phase,
    List<QuizQuestion>? questions,
    int? currentIndex,
    int? score,
    int? selectedAnswer,
    int? timeLeft,
    Set<int>? markedForReview,
    String? error,
  }) =>
      QuizSessionState(
        phase: phase ?? this.phase,
        questions: questions ?? this.questions,
        currentIndex: currentIndex ?? this.currentIndex,
        score: score ?? this.score,
        selectedAnswer: selectedAnswer,
        timeLeft: timeLeft ?? this.timeLeft,
        markedForReview: markedForReview ?? this.markedForReview,
        error: error,
      );
}

class QuizSessionNotifier extends Notifier<QuizSessionState> {
  QuizSessionNotifier({AiRepository? ai, GamificationService? gamification})
      : _ai = ai ?? AiRepository(),
        _gamification = gamification ?? GamificationService();
  final AiRepository _ai;
  final GamificationService _gamification;
  Timer? _timer;
  StreamSubscription<int>? _tickerSub;

  @override
  QuizSessionState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _tickerSub?.cancel();
    });
    return const QuizSessionState();
  }

  void setQuestions(List<QuizQuestion> qs, {int durationSeconds = 60}) {
    _timer?.cancel();
    state = QuizSessionState(
      phase: QuizPhase.playing,
      questions: qs,
      timeLeft: durationSeconds,
    );
    _startTimer();
  }

  Future<void> generateQuiz({
    required String topic,
    required String subject,
    String? gradeLevel,
    int count = 5,
    int durationSeconds = 60,
  }) async {
    state = state.copyWith(phase: QuizPhase.loading, error: null);
    final res = await _ai.generateQuiz(topic: topic, subject: subject, gradeLevel: gradeLevel, count: count);
    if (res is Success<List<Map<String, dynamic>>>) {
      final qs = res.data.map((e) => QuizQuestion.fromMap(e)).where((q) => q.question.isNotEmpty).toList();
      if (qs.isEmpty) {
        state = state.copyWith(phase: QuizPhase.setup, error: 'No questions generated. Try another topic.');
        return;
      }
      setQuestions(qs, durationSeconds: durationSeconds);
    } else if (res is Failure<List<Map<String, dynamic>>>) {
      state = state.copyWith(phase: QuizPhase.setup, error: res.message);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.timeLeft <= 1) {
        _timer?.cancel();
        finish();
      } else {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      }
    });
  }

  void selectAnswer(int index) {
    if (state.phase != QuizPhase.playing) return;
    final q = state.currentQuestion;
    if (q == null) return;
    final isCorrect = index == q.correctIndex;
    state = state.copyWith(
      selectedAnswer: index,
      score: isCorrect ? state.score + 1 : state.score,
    );
  }

  void next() {
    if (state.isLast) {
      finish();
    } else {
      state = state.copyWith(currentIndex: state.currentIndex + 1, selectedAnswer: null);
    }
  }

  void toggleMarkForReview(int index) {
    final set = Set<int>.from(state.markedForReview);
    if (set.contains(index)) {
      set.remove(index);
    } else {
      set.add(index);
    }
    state = state.copyWith(markedForReview: set);
  }

  Future<void> finish() async {
    _timer?.cancel();
    if (state.phase == QuizPhase.finished) return;
    state = state.copyWith(phase: QuizPhase.finished);
    // Record gamification — fire-and-forget local.
    if (state.questions.isNotEmpty) {
      await _gamification.recordQuizCompletion(state.score, totalQuestions: state.questions.length);
    }
  }

  void reset() {
    _timer?.cancel();
    state = const QuizSessionState();
  }
}

/// Shared quiz session — for per-screen isolation, override via ProviderScope.
final quizSessionProvider =
    NotifierProvider<QuizSessionNotifier, QuizSessionState>(QuizSessionNotifier.new);

/// Daily quiz variant — fixed 10 questions, 30s per question.
class DailyQuizNotifier extends Notifier<QuizSessionState> {
  @override
  QuizSessionState build() => const QuizSessionState();

  void startWith(List<QuizQuestion> qs) {
    state = QuizSessionState(phase: QuizPhase.playing, questions: qs, timeLeft: 30 * qs.length);
  }
}

final dailyQuizSessionProvider =
    NotifierProvider<DailyQuizNotifier, QuizSessionState>(DailyQuizNotifier.new);
