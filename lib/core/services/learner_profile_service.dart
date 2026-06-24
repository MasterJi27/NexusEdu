import 'package:shared_preferences/shared_preferences.dart';

class LearnerProfileService {
  static const String _selectedClassKey = 'selected_class';
  static const String _completedShortsKey = 'completed_short_ids';

  static Future<String?> getSelectedClass() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_selectedClassKey);
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static Future<void> setSelectedClass(String? className) async {
    final prefs = await SharedPreferences.getInstance();
    if (className == null || className.trim().isEmpty) {
      await prefs.remove(_selectedClassKey);
      return;
    }
    await prefs.setString(_selectedClassKey, className.trim());
  }

  static Future<Set<String>> getCompletedShortIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedShortsKey) ?? const <String>[])
        .toSet();
  }

  static Future<void> markShortCompleted(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = (prefs.getStringList(_completedShortsKey) ?? <String>[])
        .toSet();
    completed.add(videoId);
    await prefs.setStringList(_completedShortsKey, completed.toList()..sort());
  }
}
