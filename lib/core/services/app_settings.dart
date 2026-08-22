import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _examDateKey = 'exam_target_date';
  static const _examNameKey = 'exam_name';
  static const _streakKey = 'study_streak';
  static const _streakDateKey = 'last_study_date';
  static const _streakSaverKey = 'streak_saver_used';
  static const _dailyMinutesKey = 'daily_minutes_goal';
  static const _pomodoroWorkKey = 'pomodoro_work_min';
  static const _pomodoroBreakKey = 'pomodoro_break_min';
  static const _pomodoroSessionsKey = 'pomodoro_sessions_today';
  static const _pomodoroSessionDateKey = 'pomodoro_session_date';
  static const _notesCacheKey = 'cached_notes';
  static const _languageKey = 'ui_language';
  static const _flashcardDecksKey = 'flashcard_decks';
  static const _curriculumKey = 'curriculum_data';
  static const _reviewScheduleKey = 'review_schedule_items';
  static const _accentKey = 'org_accent_color';
  static const _classNotesCacheKey = 'cached_class_notes';
  static const _teacherTasksCacheKey = 'cached_teacher_tasks';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  DateTime? _examDate;
  DateTime? get examDate => _examDate;

  String _examName = 'Exam';
  String get examName => _examName;

  int _streak = 0;
  int get streak => _streak;

  bool _streakSaverUsed = false;

  /// One free missed day per streak cycle: when a day is skipped the streak
  /// is kept instead of reset, and the shield is consumed until the streak
  /// is continued again.
  bool get streakSaverUsed => _streakSaverUsed;

  /// The calendar day of the last study activity, 'YYYY-MM-DD' or ''.
  String _lastStudyDate = '';
  String get lastStudyDate => _lastStudyDate;

  int _dailyMinutesGoal = 30;
  int get dailyMinutesGoal => _dailyMinutesGoal;

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

  List<Map<String, dynamic>> _cachedClassNotes = [];
  List<Map<String, dynamic>> get cachedClassNotes => _cachedClassNotes;

  List<Map<String, dynamic>> _cachedTasks = [];
  List<Map<String, dynamic>> get cachedTasks => _cachedTasks;

  /// Organization accent color ('#RRGGBB' or '#AARRGGBB'), synced from the
  /// server profile. Null = the default Nexus Edu navy. Drives the whole
  /// theme through AppTheme.lightThemeWith/darkThemeWith in main.dart.
  String? _accentColor;
  String? get accentColor => _accentColor;

  SharedPreferences? _prefs;

  // Fixed P0: was `await _getPrefs()` — infinite recursion / stack overflow.
  // Correctly lazy-initializes the singleton via SharedPreferences.getInstance().
  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static AppSettings? _instance;
  static AppSettings get instance => _instance ??= AppSettings._();
  AppSettings._();

  /// Decodes a stored entry: JSON first, then the legacy `key=value|key=value`
  /// codec older builds wrote. Returns null only if neither matches.
  static Map<String, dynamic>? tryDecode(String e) {
    try {
      final decoded = json.decode(e);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // fall through to legacy codec
    }
    final map = <String, dynamic>{};
    for (final part in e.split('|')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0]] = kv[1];
    }
    return map.isEmpty ? null : map;
  }

  Future<void> load() async {
    final prefs = await _getPrefs();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _themeMode = ThemeMode.values[themeIndex];
    _examDate = prefs.getString(_examDateKey) != null
        ? DateTime.tryParse(prefs.getString(_examDateKey)!)
        : null;
    _examName = prefs.getString(_examNameKey) ?? 'Exam';
    _streak = prefs.getInt(_streakKey) ?? 0;
    _streakSaverUsed = prefs.getBool(_streakSaverKey) ?? false;
    _lastStudyDate = prefs.getString(_streakDateKey) ?? '';
    _dailyMinutesGoal = prefs.getInt(_dailyMinutesKey) ?? 30;
    _pomodoroWork = prefs.getInt(_pomodoroWorkKey) ?? 25;
    _pomodoroBreak = prefs.getInt(_pomodoroBreakKey) ?? 5;
    _pomodoroSessionsToday = prefs.getInt(_pomodoroSessionsKey) ?? 0;
    _language = prefs.getString(_languageKey) ?? 'en';
    _accentColor = prefs.getString(_accentKey);
    final notesJson = prefs.getStringList(_notesCacheKey);
    if (notesJson != null) {
      _cachedNotes = notesJson
          .map((e) => tryDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    final decksJson = prefs.getStringList(_flashcardDecksKey);
    if (decksJson != null) {
      _flashcardDecks = decksJson
          .map((e) => tryDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    final curJson = prefs.getStringList(_curriculumKey);
    if (curJson != null) {
      _curriculum = curJson
          .map((e) => tryDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    final revJson = prefs.getStringList(_reviewScheduleKey);
    if (revJson != null) {
      _reviewSchedule = revJson
          .map((e) => tryDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    final classNotesJson = prefs.getStringList(_classNotesCacheKey);
    if (classNotesJson != null) {
      _cachedClassNotes = classNotesJson
          .map((e) => tryDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    final tasksJson = prefs.getStringList(_teacherTasksCacheKey);
    if (tasksJson != null) {
      _cachedTasks = tasksJson
          .map((e) => tryDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    await _updateStreak(prefs);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await _getPrefs();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setExamDate(DateTime date, String name) async {
    _examDate = date;
    _examName = name;
    final prefs = await _getPrefs();
    await prefs.setString(_examDateKey, date.toIso8601String());
    await prefs.setString(_examNameKey, name);
    notifyListeners();
  }

  Future<void> clearExamDate() async {
    _examDate = null;
    final prefs = await _getPrefs();
    await prefs.remove(_examDateKey);
    await prefs.remove(_examNameKey);
    notifyListeners();
  }

  Future<void> setPomodoroSettings(int work, int brk) async {
    _pomodoroWork = work;
    _pomodoroBreak = brk;
    final prefs = await _getPrefs();
    await prefs.setInt(_pomodoroWorkKey, work);
    await prefs.setInt(_pomodoroBreakKey, brk);
    notifyListeners();
  }

  Future<void> incrementPomodoroSessions() async {
    final prefs = await _getPrefs();
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
    final prefs = await _getPrefs();
    await prefs.setString(_languageKey, lang);
    notifyListeners();
  }

  /// Persists the org accent color (or clears it with null). notifyListeners
  /// rebuilds the app theme in main.dart.
  Future<void> setAccentColor(String? hex) async {
    if (hex == _accentColor) return;
    _accentColor = hex;
    final prefs = await _getPrefs();
    if (hex == null) {
      await prefs.remove(_accentKey);
    } else {
      await prefs.setString(_accentKey, hex);
    }
    notifyListeners();
  }

  /// P1-07: SharedPreferences 800KB guard — extracted helper so every
  /// cache write enforces the same cap. Truncates to 400 most-recent when
  /// 800KB is exceeded and emits a debugPrint for diagnostics.
  // TODO(P1-07): verified 2026-08-21 — _enforceCap used in saveFlashcardDecks, addFlashcardDeck, deleteFlashcardDeck, updateFlashcardDeck, saveReviewSchedule (and all other cache writes) — already fixed.
  List<Map<String, dynamic>> _enforceCap(List<Map<String, dynamic>> list) {
    final encoded = list.map((e) => json.encode(e)).toList();
    final totalBytes = encoded.fold<int>(0, (sum, e) => sum + e.length);
    if (totalBytes > 800 * 1024) {
      debugPrint(
        'AppSettings: _enforceCap exceeds 800KB ($totalBytes bytes, ${encoded.length} items) — truncating to 400 most recent',
      );
      return list.take(400).toList();
    }
    return list;
  }

  Future<void> saveCachedNotes(List<Map<String, dynamic>> notes) async {
    // 1M-scale SharedPreferences guard: cap at 800KB, truncate to 400 most recent.
    final toStore = _enforceCap(notes);
    _cachedNotes = toStore;
    final prefs = await _getPrefs();
    final encoded = toStore.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_notesCacheKey, encoded);
    // No notifyListeners: notes are consumed via Riverpod `notesProvider`,
    // not via AppSettings listen. Avoids rebuilding MaterialApp on every note save.
  }

  Future<void> addCachedNote(Map<String, dynamic> note) async {
    _cachedNotes.insert(0, note);
    _cachedNotes = _enforceCap(_cachedNotes);
    final prefs = await _getPrefs();
    final encoded = _cachedNotes.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_notesCacheKey, encoded);
  }

  Future<void> deleteCachedNote(int index) async {
    _cachedNotes.removeAt(index);
    // Not strictly needed (deletion shrinks), but call for consistency
    // so every write path goes through the cap guard.
    _cachedNotes = _enforceCap(_cachedNotes);
    final prefs = await _getPrefs();
    final encoded = _cachedNotes.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_notesCacheKey, encoded);
  }

  Future<void> saveFlashcardDecks(List<Map<String, dynamic>> decks) async {
    final toStore = _enforceCap(decks);
    _flashcardDecks = toStore;
    final prefs = await _getPrefs();
    final encoded = toStore.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
  }

  Future<void> addFlashcardDeck(Map<String, dynamic> deck) async {
    _flashcardDecks.insert(0, deck);
    _flashcardDecks = _enforceCap(_flashcardDecks);
    final prefs = await _getPrefs();
    final encoded = _flashcardDecks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
  }

  Future<void> deleteFlashcardDeck(int index) async {
    _flashcardDecks.removeAt(index);
    _flashcardDecks = _enforceCap(_flashcardDecks);
    final prefs = await _getPrefs();
    final encoded = _flashcardDecks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
  }

  Future<void> updateFlashcardDeck(int index, Map<String, dynamic> deck) async {
    _flashcardDecks[index] = deck;
    _flashcardDecks = _enforceCap(_flashcardDecks);
    final prefs = await _getPrefs();
    final encoded = _flashcardDecks.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_flashcardDecksKey, encoded);
  }

  Future<void> saveCurriculum(List<Map<String, dynamic>> data) async {
    // P1-07: enforce 800KB cap via _enforceCap for consistency.
    final toStore = _enforceCap(data);
    _curriculum = toStore;
    final prefs = await _getPrefs();
    await prefs.setStringList(
      _curriculumKey,
      toStore.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> saveReviewSchedule(List<Map<String, dynamic>> items) async {
    final toStore = _enforceCap(items);
    _reviewSchedule = toStore;
    final prefs = await _getPrefs();
    await prefs.setStringList(
      _reviewScheduleKey,
      toStore.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> saveCachedClassNotes(List<Map<String, dynamic>> notes) async {
    // 1M-scale SharedPreferences guard via _enforceCap (800KB -> 400 items).
    final toStore = _enforceCap(notes);
    _cachedClassNotes = toStore;
    final prefs = await _getPrefs();
    final encoded = toStore.map((e) => json.encode(e)).toList();
    await prefs.setStringList(_classNotesCacheKey, encoded);
  }

  Future<void> saveCachedTasks(List<Map<String, dynamic>> tasks) async {
    // P1-07: enforce 800KB cap via _enforceCap for consistency.
    final toStore = _enforceCap(tasks);
    _cachedTasks = toStore;
    final prefs = await _getPrefs();
    await prefs.setStringList(
      _teacherTasksCacheKey,
      toStore.map((e) => json.encode(e)).toList(),
    );
  }

  /// Pure streak rule, extracted for tests. Returns the new (streak, saverUsed).
  /// `lastStudyDate` is 'YYYY-MM-DD' or ''.
  static (int, bool) computeStreak(
    int currentStreak,
    String lastStudyDate,
    bool saverUsed,
    DateTime today,
  ) {
    if (lastStudyDate.isEmpty) return (1, false);
    final lastDate = DateTime.tryParse(lastStudyDate);
    if (lastDate == null) return (1, false);

    final diff = today
        .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
        .inDays;
    if (diff == 0) return (currentStreak, saverUsed);
    if (diff == 1) return (currentStreak + 1, false);
    if (diff == 2 && !saverUsed) return (currentStreak, true);
    return (1, false);
  }

  Future<void> _updateStreak(SharedPreferences prefs) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final lastDateStr = prefs.getString(_streakDateKey) ?? '';
    _lastStudyDate = lastDateStr;

    if (lastDateStr == todayStr) return;

    final (newStreak, newSaverUsed) = computeStreak(
      _streak,
      lastDateStr,
      _streakSaverUsed,
      today,
    );
    _streak = newStreak;
    _streakSaverUsed = newSaverUsed;
    _lastStudyDate = todayStr;
    await prefs.setString(_streakDateKey, todayStr);
    await prefs.setInt(_streakKey, _streak);
    await prefs.setBool(_streakSaverKey, _streakSaverUsed);
  }

  /// The student's daily study target in minutes; drives the focus timer and
  /// the dashboard's daily goal banner.
  Future<void> setDailyMinutesGoal(int minutes) async {
    _dailyMinutesGoal = minutes;
    final prefs = await _getPrefs();
    await prefs.setInt(_dailyMinutesKey, minutes);
    notifyListeners();
  }
}
