import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A JSON-encoded list of maps persisted under one `SharedPreferences` key —
/// the "load, decode each entry" / "encode each entry, save" shape that five
/// screens (mock test results, JEE/NEET results, revision history, study
/// planner history, math solutions) used to each reimplement by hand under
/// their own ad-hoc key. Capping/ordering stays with the caller, since it
/// differs per screen (some cap oldest-out at the front, one at the back).
class LocalHistoryStore {
  const LocalHistoryStore(this.key);

  final String key;

  Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key) ?? [];
    return saved
        .map((e) => Map<String, dynamic>.from(json.decode(e)))
        .toList();
  }

  Future<void> save(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, entries.map((e) => json.encode(e)).toList());
  }
}
