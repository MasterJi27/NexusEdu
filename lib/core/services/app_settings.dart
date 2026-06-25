import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _examDateKey = 'exam_target_date';
  static const _examNameKey = 'exam_name';
  static const _streakKey = 'study_streak';
  static const _streakDateKey = 'last_study_date';
  static const _pomodoroWorkKey = 'pomodoro_work_min';
  static const _pomodoroBreakKey = 'pomodoro_break_min';
  static const _pomodoroSessionsKey = 'pomodoro_sessions_today';
  static const _pomodoroSessionDateKey = 'pomodoro_session_date';
  static const _notesCacheKey = 'cached_notes';
  static const _languageKey = 'ui_language';
  static const _flashcardDecksKey = 'flashcard_decks';
  static const _curriculumKey = 'curriculum_data';
  static const _reviewScheduleKey = 'review_schedule_items';
  static const _swarmAgentScoresKey = 'swarm_agent_scores';
  static const _dreamJournalKey = 'dream_journal';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  DateTime? _examDate;
  DateTime? get examDate => _examDate;

  String _examName = 'Exam';
  String get examName => _examName;

  int _streak = 0;
  int get streak => _streak;

  int _pomodoroWork = 25;
  int get pomodoroWork => _pomodoroWork;

  int _pomodoroBreak = 5;
  int get pomodoroBreak => _pomodoroBreak;

  int _pomodoroSessionsToday = 0;
  int get pomodoroSessionsToday => _pomodoroSessionsToday;

  String _language = 'en';
  String get language => _language;

  List<Map<String, dynamic>> _cachedNotes = [];
  List<Map<String, dynamic>> get cachedNotes => _cachedNotes;

  List<Map<String, dynamic>> _flashcardDecks = [];
  List<Map<String, dynamic>> get flashcardDecks => _flashcardDecks;

  List<Map<String, dynamic>> _curriculum = [];
  List<Map<String, dynamic>> get curriculum => _curriculum;

  List<Map<String, dynamic>> _reviewSchedule = [];
  List<Map<String, dynamic>> get reviewSchedule => _reviewSchedule;

  List<Map<String, dynamic>> _swarmAgentScores = [];
  List<Map<String, dynamic>> get swarmAgentScores => _swarmAgentScores;

  List<Map<String, dynamic>> _dreamJournal = [];
  List<Map<String, dynamic>> get dreamJournal => _dreamJournal;

  static AppSettings? _instance;
  static AppSettings get instance => _instance ??= AppSettings._();
  AppSettings._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _themeMode = ThemeMode.values[themeIndex];
    _examDate = prefs.getString(_examDateKey) != null
        ? DateTime.tryParse(prefs.getString(_examDateKey)!)
        : null;
    _examName = prefs.getString(_examNameKey) ?? 'Exam';
    _streak = prefs.getInt(_streakKey) ?? 0;
    _pomodoroWork = prefs.getInt(_pomodoroWorkKey) ?? 25;
    _pomodoroBreak = prefs.getInt(_pomodoroBreakKey) ?? 5;
    _pomodoroSessionsToday = prefs.getInt(_pomodoroSessionsKey) ?? 0;
    _language = prefs.getString(_languageKey) ?? 'en';
    final notesJson = prefs.getStringList(_notesCacheKey);
    if (notesJson != null) {
      _cachedNotes = notesJson
          .map((e) => Map<String, dynamic>.from(_decodeJson(e)))
          .toList();
    }
    final decksJson = prefs.getStringList(_flashcardDecksKey);
    if (decksJson != null) {
      _flashcardDecks = decksJson
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    }
    final curJson = prefs.getStringList(_curriculumKey);
    if (curJson != null) {
      _curriculum = curJson
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    }
    final revJson = prefs.getStringList(_reviewScheduleKey);
    if (revJson != null) {
      _reviewSchedule = revJson
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    }
    final swarmJson = prefs.getStringList(_swarmAgentScoresKey);
    if (swarmJson != null) {
      _swarmAgentScores = swarmJson
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    }
    final dreamJson = prefs.getStringList(_dreamJournalKey);
    if (dreamJson != null) {
      _dreamJournal = dreamJson
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
    }
    _updateStreak(prefs);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setExamDate(DateTime date, String name) async {
    _examDate = date;
    _examName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_examDateKey, date.toIso8601String());
    await prefs.setString(_examNameKey, name);
    notifyListeners();
  }

  Future<void> clearExamDate() async {
    _examDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_examDateKey);
    await prefs.remove(_examNameKey);
    notifyListeners();
  }

  Future<void> setPomodoroSettings(int work, int brk) async {
    _pomodoroWork = work;
    _pomodoroBreak = brk;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pomodoroWorkKey, work);
    await prefs.setInt(_pomodoroBreakKey, brk);
    notifyListeners();
  }

  Future<void> incrementPomodoroSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_pomodoroSessionDateKey) ?? '';
    if (savedDate != today) {
      _pomodoroSessionsToday = 1;
      await prefs.setString(_pomodoroSessionDateKey, today);
    } else {
      _pomodoroSessionsToday++;
    }
    await prefs.setInt(_pomodoroSessionsKey, _pomodoroSessionsToday);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
    notifyListeners();
  }

  Future<void> saveCachedNotes(List<Map<String, dynamic>> notes) async {
    _cachedNotes = notes;
    final prefs = await SharedPreferences.getInstance();
    final encoded = notes.map((e) => _encodeJson(e)).toList();
    await prefs.setStringList(_notesCacheKey, encoded);
    notifyListeners();
  }

  Future<void> addCachedNote(Map<String, dynamic> note) async {
    _cachedNotes.insert(0, note);
    final prefs = await SharedPreferences.getInstance();
    final encoded = _cachedNotes.map((e) => _encodeJson(e)).toList();
    await prefs.setStringList(_notesCacheKey, encoded);
    notifyListeners();
  }

  Future<void> deleteCachedNote(int index) async {
    _cachedNotes.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    final encoded = _cachedNotes.map((e) => _encodeJson(e)).toList();
    await prefs.setStringList(_notesCacheKey, encoded);
    notifyListeners();
  }

  Future<void> saveFlashcardDecks(List<Map<String, dynamic>> decks) async {
    _flashcardDecks = decks;
    final prefs = await SharedPreferences.getInstance();
    final encoded = decks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
    notifyListeners();
  }

  Future<void> addFlashcardDeck(Map<String, dynamic> deck) async {
    _flashcardDecks.insert(0, deck);
    final prefs = await SharedPreferences.getInstance();
    final encoded = _flashcardDecks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
    notifyListeners();
  }

  Future<void> deleteFlashcardDeck(int index) async {
    _flashcardDecks.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    final encoded = _flashcardDecks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
    notifyListeners();
  }

  Future<void> updateFlashcardDeck(int index, Map<String, dynamic> deck) async {
    _flashcardDecks[index] = deck;
    final prefs = await SharedPreferences.getInstance();
    final encoded = _flashcardDecks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
    notifyListeners();
  }

  Future<void> saveCurriculum(List<Map<String, dynamic>> data) async {
    _curriculum = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _curriculumKey,
      data.map((e) => json.encode(e)).toList(),
    );
    notifyListeners();
  }

  Future<void> saveReviewSchedule(List<Map<String, dynamic>> items) async {
    _reviewSchedule = items;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _reviewScheduleKey,
      items.map((e) => json.encode(e)).toList(),
    );
    notifyListeners();
  }

  Future<void> saveSwarmAgentScores(List<Map<String, dynamic>> agents) async {
    _swarmAgentScores = agents;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _swarmAgentScoresKey,
      agents.map((e) => json.encode(e)).toList(),
    );
    notifyListeners();
  }

  Future<void> saveDreamJournal(List<Map<String, dynamic>> entries) async {
    _dreamJournal = entries;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dreamJournalKey,
      entries.map((e) => json.encode(e)).toList(),
    );
    notifyListeners();
  }

  void _updateStreak(SharedPreferences prefs) {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final lastDateStr = prefs.getString(_streakDateKey) ?? '';

    if (lastDateStr == todayStr) return;

    if (lastDateStr.isEmpty) {
      _streak = 1;
      prefs.setString(_streakDateKey, todayStr);
      prefs.setInt(_streakKey, _streak);
      return;
    }

    final lastDate = DateTime.tryParse(lastDateStr);
    if (lastDate == null) {
      _streak = 1;
      prefs.setString(_streakDateKey, todayStr);
      prefs.setInt(_streakKey, _streak);
      return;
    }

    final diff = today
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;
    if (diff == 1) {
      _streak++;
    } else if (diff > 1) {
      _streak = 1;
    }
    prefs.setString(_streakDateKey, todayStr);
    prefs.setInt(_streakKey, _streak);
  }

  String _encodeJson(Map<String, dynamic> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  Map<String, dynamic> _decodeJson(String str) {
    final map = <String, dynamic>{};
    for (final part in str.split('|')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0]] = kv[1];
    }
    return map;
  }
}
