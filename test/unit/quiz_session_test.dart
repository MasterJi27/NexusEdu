import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/shared/providers/quiz_session_provider.dart';

void main() {
  group('QuizSessionState', () {
    test('initial state is setup', () {
      const s = QuizSessionState();
      expect(s.phase, QuizPhase.setup);
      expect(s.score, 0);
      expect(s.currentIndex, 0);
      expect(s.isFinished, isFalse);
    });

    test('copyWith updates correctly', () {
      const s = QuizSessionState(phase: QuizPhase.playing, score: 1);
      final s2 = s.copyWith(score: 2, timeLeft: 30);
      expect(s2.score, 2);
      expect(s2.timeLeft, 30);
      expect(s2.phase, QuizPhase.playing);
    });

    test('isLast and currentQuestion', () {
      final qs = [
        QuizQuestion(question: 'Q1', options: ['A', 'B'], correctIndex: 0),
        QuizQuestion(question: 'Q2', options: ['A', 'B'], correctIndex: 1),
      ];
      final s = QuizSessionState(questions: qs, currentIndex: 1);
      expect(s.isLast, isTrue);
      expect(s.currentQuestion?.question, 'Q2');
    });

    test('QuizQuestion fromMap parses correctIndex variants', () {
      final q = QuizQuestion.fromMap({
        'question': 'What is 2+2?',
        'options': ['3', '4'],
        'correctIndex': 1,
      });
      expect(q.correctIndex, 1);
      final q2 = QuizQuestion.fromMap({
        'question': 'Q',
        'options': ['A', 'B'],
        'correct': 0,
      });
      expect(q2.correctIndex, 0);
    });

    test('markedForReview toggle logic', () {
      const s = QuizSessionState(markedForReview: {1});
      final added = s.copyWith(markedForReview: {...s.markedForReview, 2});
      expect(added.markedForReview, contains(2));
      final removed = QuizSessionState(markedForReview: {1, 2}).copyWith(markedForReview: {2});
      expect(removed.markedForReview, isNot(contains(1)));
    });
  });
}
