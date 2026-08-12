import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._();
  factory GamificationService() => _instance;
  GamificationService._();

  int _xp = 0;
  int _level = 1;
  int _totalStudyMinutes = 0;
  int _quizzesCompleted = 0;
  int _avgQuizScore = 0;
  List<String> _badges = [];

  /// Reads through to [AppSettings], the single source of truth for the
  /// streak count. This used to keep its own `_streak` field and independent
  /// `last_study_date`/`streak` prefs keys that collided with AppSettings's —
  /// same key, two writers, so whichever saved last won and the two could
  /// disagree on-screen (e.g. the dashboard header vs. the streak banner).
  int get streak => AppSettings.instance.streak;
  int get xp => _xp;
  int get level => _level;
  int get totalStudyMinutes => _totalStudyMinutes;
  int get quizzesCompleted => _quizzesCompleted;
  int get avgQuizScore => _avgQuizScore;
  List<String> get badges => List.unmodifiable(_badges);

  int get xpForNextLevel => _level * 500;
  int get xpProgress => _xp % xpForNextLevel;
  double get levelProgress => xpProgress / xpForNextLevel;

  /// One-time-per-day bonus for the first finished quiz (activation pattern:
  /// an immediate, visible reward for the first win of the day).
  static const int firstWinBonusXp = 15;
  bool _firstWinEarnedToday = false;
  bool get firstWinEarnedToday => _firstWinEarnedToday;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _xp = prefs.getInt('xp') ?? 0;
    _level = prefs.getInt('level') ?? 1;
    _totalStudyMinutes = prefs.getInt('total_study_minutes') ?? 0;
    _quizzesCompleted = prefs.getInt('quizzes_completed') ?? 0;
    _avgQuizScore = prefs.getInt('avg_quiz_score') ?? 0;
    await _migrateAvgQuizScoreUnits(prefs);
    _badges = prefs.getStringList('badges') ?? [];
    final bonusDate = prefs.getString('first_win_bonus_date') ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _firstWinEarnedToday = bonusDate == today;
  }

  /// Older builds stored `avg_quiz_score` as a raw correct-answer count rather
  /// than a percentage, so an existing user's average would blend the two units
  /// once the corrected value starts being written. There is no denominator
  /// recorded for those old quizzes, so the honest move is to drop the
  /// un-interpretable history rather than rescale it with a guessed quiz
  /// length: the average simply restarts from the next quiz.
  Future<void> _migrateAvgQuizScoreUnits(SharedPreferences prefs) async {
    const migratedKey = 'avg_quiz_score_is_percent';
    if (prefs.getBool(migratedKey) ?? false) return;
    _avgQuizScore = 0;
    await prefs.setInt('avg_quiz_score', 0);
    await prefs.setBool(migratedKey, true);
  }

  /// Records a finished quiz. [correctAnswers] out of [totalQuestions].
  ///
  /// [_avgQuizScore] is a *percentage*, which is how every screen labels it.
  /// Callers used to pass the raw correct-answer count with no denominator, so
  /// a perfect 10-question quiz was averaged in as "10" and then rendered as
  /// "10%". XP still scales with raw answers, so scoring is unchanged.
  Future<void> recordQuizCompletion(
    int correctAnswers, {
    required int totalQuestions,
  }) async {
    final percent = totalQuestions > 0
        ? ((correctAnswers / totalQuestions) * 100).round()
        : 0;
    _quizzesCompleted++;
    final total = _avgQuizScore * (_quizzesCompleted - 1);
    _avgQuizScore = ((total + percent) / _quizzesCompleted).round();
    _xp += (correctAnswers * 2);
    if (!_firstWinEarnedToday) {
      _firstWinEarnedToday = true;
      _xp += firstWinBonusXp;
    }
    _checkLevelUp();
    _save();
    _checkBadges();
  }

  void _checkLevelUp() {
    while (_xp >= _level * 500) {
      _level++;
    }
  }

  void _checkBadges() {
    if (streak >= 3 && !_badges.contains('🔥 3-Day Streak')) _badges.add('🔥 3-Day Streak');
    if (streak >= 7 && !_badges.contains('🔥 7-Day Streak')) _badges.add('🔥 7-Day Streak');
    if (streak >= 30 && !_badges.contains('🔥 30-Day Streak')) _badges.add('🔥 30-Day Streak');
    if (_quizzesCompleted >= 10 && !_badges.contains('📝 10 Quizzes')) _badges.add('📝 10 Quizzes');
    if (_quizzesCompleted >= 50 && !_badges.contains('📝 50 Quizzes')) _badges.add('📝 50 Quizzes');
    if (_avgQuizScore >= 90 && !_badges.contains('⭐ 90% Average')) _badges.add('⭐ 90% Average');
    if (_totalStudyMinutes >= 1000 && !_badges.contains('📚 1000 Min')) _badges.add('📚 1000 Min');
    if (_level >= 10 && !_badges.contains('🏆 Level 10')) _badges.add('🏆 Level 10');
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('xp', _xp);
    await prefs.setInt('level', _level);
    await prefs.setInt('total_study_minutes', _totalStudyMinutes);
    await prefs.setInt('quizzes_completed', _quizzesCompleted);
    await prefs.setInt('avg_quiz_score', _avgQuizScore);
    await prefs.setStringList('badges', _badges);
    await prefs.setString(
      'first_win_bonus_date',
      _firstWinEarnedToday
          ? DateTime.now().toIso8601String().substring(0, 10)
          : '',
    );
  }

  String get levelTitle {
    if (_level >= 20) return 'Master';
    if (_level >= 15) return 'Expert';
    if (_level >= 10) return 'Advanced';
    if (_level >= 5) return 'Intermediate';
    return 'Beginner';
  }


}
