import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._();
  factory GamificationService() => _instance;
  GamificationService._();

  int _streak = 0;
  int _xp = 0;
  int _level = 1;
  int _totalStudyMinutes = 0;
  int _quizzesCompleted = 0;
  int _avgQuizScore = 0;
  int _leaderboardRank = 127;
  DateTime? _lastStudyDate;
  DateTime? _lastQuizDate;
  List<String> _badges = [];

  int get streak => _streak;
  int get xp => _xp;
  int get level => _level;
  int get totalStudyMinutes => _totalStudyMinutes;
  int get quizzesCompleted => _quizzesCompleted;
  int get avgQuizScore => _avgQuizScore;
  int get leaderboardRank => _leaderboardRank;
  List<String> get badges => List.unmodifiable(_badges);

  int get xpForNextLevel => _level * 500;
  int get xpProgress => _xp % xpForNextLevel;
  double get levelProgress => xpProgress / xpForNextLevel;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt('streak') ?? 0;
    _xp = prefs.getInt('xp') ?? 0;
    _level = prefs.getInt('level') ?? 1;
    _totalStudyMinutes = prefs.getInt('total_study_minutes') ?? 0;
    _quizzesCompleted = prefs.getInt('quizzes_completed') ?? 0;
    _avgQuizScore = prefs.getInt('avg_quiz_score') ?? 0;
    _leaderboardRank = prefs.getInt('leaderboard_rank') ?? 127;
    _badges = prefs.getStringList('badges') ?? [];
    final lastStudy = prefs.getString('last_study_date');
    if (lastStudy != null) _lastStudyDate = DateTime.tryParse(lastStudy);
    final lastQuiz = prefs.getString('last_quiz_date');
    if (lastQuiz != null) _lastQuizDate = DateTime.tryParse(lastQuiz);
    _checkStreakReset();
  }

  void _checkStreakReset() {
    if (_lastStudyDate == null) return;
    final now = DateTime.now();
    final lastDay = DateTime(_lastStudyDate!.year, _lastStudyDate!.month, _lastStudyDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(lastDay).inDays;
    if (diff > 1) {
      _streak = 0;
      _save();
    }
  }

  Future<void> recordStudySession(int minutes) async {
    final now = DateTime.now();
    final lastDay = _lastStudyDate != null
        ? DateTime(_lastStudyDate!.year, _lastStudyDate!.month, _lastStudyDate!.day)
        : null;
    final today = DateTime(now.year, now.month, now.day);
    if (lastDay == null || today.difference(lastDay).inDays >= 1) {
      if (lastDay != null && today.difference(lastDay).inDays == 1) {
        _streak++;
      } else {
        _streak = 1;
      }
    }
    _lastStudyDate = now;
    _totalStudyMinutes += minutes;
    final xpEarned = minutes * 5;
    _xp += xpEarned;
    _checkLevelUp();
    _save();
    _checkBadges();
  }

  Future<void> recordQuizCompletion(int score) async {
    _quizzesCompleted++;
    final total = _avgQuizScore * (_quizzesCompleted - 1);
    _avgQuizScore = ((total + score) / _quizzesCompleted).round();
    _xp += (score * 2);
    _checkLevelUp();
    _lastQuizDate = DateTime.now();
    _save();
    _checkBadges();
  }

  void _checkLevelUp() {
    while (_xp >= _level * 500) {
      _level++;
    }
  }

  void _checkBadges() {
    if (_streak >= 3 && !_badges.contains('🔥 3-Day Streak')) _badges.add('🔥 3-Day Streak');
    if (_streak >= 7 && !_badges.contains('🔥 7-Day Streak')) _badges.add('🔥 7-Day Streak');
    if (_streak >= 30 && !_badges.contains('🔥 30-Day Streak')) _badges.add('🔥 30-Day Streak');
    if (_quizzesCompleted >= 10 && !_badges.contains('📝 10 Quizzes')) _badges.add('📝 10 Quizzes');
    if (_quizzesCompleted >= 50 && !_badges.contains('📝 50 Quizzes')) _badges.add('📝 50 Quizzes');
    if (_avgQuizScore >= 90 && !_badges.contains('⭐ 90% Average')) _badges.add('⭐ 90% Average');
    if (_totalStudyMinutes >= 1000 && !_badges.contains('📚 1000 Min')) _badges.add('📚 1000 Min');
    if (_level >= 10 && !_badges.contains('🏆 Level 10')) _badges.add('🏆 Level 10');
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak', _streak);
    await prefs.setInt('xp', _xp);
    await prefs.setInt('level', _level);
    await prefs.setInt('total_study_minutes', _totalStudyMinutes);
    await prefs.setInt('quizzes_completed', _quizzesCompleted);
    await prefs.setInt('avg_quiz_score', _avgQuizScore);
    await prefs.setInt('leaderboard_rank', _leaderboardRank);
    await prefs.setStringList('badges', _badges);
    if (_lastStudyDate != null) {
      await prefs.setString('last_study_date', _lastStudyDate!.toIso8601String());
    }
    if (_lastQuizDate != null) {
      await prefs.setString('last_quiz_date', _lastQuizDate!.toIso8601String());
    }
  }

  String get levelTitle {
    if (_level >= 20) return 'Master';
    if (_level >= 15) return 'Expert';
    if (_level >= 10) return 'Advanced';
    if (_level >= 5) return 'Intermediate';
    return 'Beginner';
  }

  String get rankTitle {
    if (_leaderboardRank <= 10) return 'Top 10';
    if (_leaderboardRank <= 50) return 'Top 50';
    if (_leaderboardRank <= 100) return 'Top 100';
    return 'Rising Star';
  }

  static final List<Map<String, dynamic>> leaderboard = [
    {'name': 'Priya S.', 'xp': 4850, 'rank': 1, 'streak': 14},
    {'name': 'Aarav M.', 'xp': 4200, 'rank': 2, 'streak': 10},
    {'name': 'You', 'xp': 2450, 'rank': 3, 'streak': 7, 'isUser': true},
    {'name': 'Rahul K.', 'xp': 1800, 'rank': 4, 'streak': 5},
    {'name': 'Ananya R.', 'xp': 1650, 'rank': 5, 'streak': 4},
    {'name': 'Vikram P.', 'xp': 1500, 'rank': 6, 'streak': 3},
    {'name': 'Sneha G.', 'xp': 1350, 'rank': 7, 'streak': 6},
    {'name': 'Arjun T.', 'xp': 1200, 'rank': 8, 'streak': 2},
    {'name': 'Kavya N.', 'xp': 1100, 'rank': 9, 'streak': 8},
    {'name': 'Rohan D.', 'xp': 950, 'rank': 10, 'streak': 1},
  ];
}
