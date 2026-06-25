import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SubjectProgress {
  final String name;
  final String icon;
  final int totalChapters;
  int completedChapters;
  double avgScore;
  DateTime? lastStudied;

  SubjectProgress({
    required this.name,
    required this.icon,
    required this.totalChapters,
    this.completedChapters = 0,
    this.avgScore = 0,
    this.lastStudied,
  });

  double get progress => totalChapters > 0 ? completedChapters / totalChapters : 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': icon,
    'totalChapters': totalChapters,
    'completedChapters': completedChapters,
    'avgScore': avgScore,
    'lastStudied': lastStudied?.toIso8601String(),
  };

  factory SubjectProgress.fromJson(Map<String, dynamic> json) => SubjectProgress(
    name: json['name'],
    icon: json['icon'],
    totalChapters: json['totalChapters'],
    completedChapters: json['completedChapters'] ?? 0,
    avgScore: (json['avgScore'] ?? 0).toDouble(),
    lastStudied: json['lastStudied'] != null ? DateTime.tryParse(json['lastStudied']) : null,
  );
}

class SubjectProgressService {
  static final SubjectProgressService _instance = SubjectProgressService._();
  factory SubjectProgressService() => _instance;
  SubjectProgressService._();

  List<SubjectProgress> _subjects = [];

  List<SubjectProgress> get subjects => List.unmodifiable(_subjects);

  double get overallProgress {
    if (_subjects.isEmpty) return 0;
    final total = _subjects.fold(0, (sum, s) => sum + s.totalChapters);
    final completed = _subjects.fold(0, (sum, s) => sum + s.completedChapters);
    return total > 0 ? completed / total : 0;
  }

  int get totalChapters => _subjects.fold(0, (sum, s) => sum + s.totalChapters);
  int get completedChapters => _subjects.fold(0, (sum, s) => sum + s.completedChapters);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('subject_progress');
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _subjects = json.map((j) => SubjectProgress.fromJson(j)).toList();
    } else {
      _subjects = _getDefaultSubjects();
      await save();
    }
  }

  List<SubjectProgress> _getDefaultSubjects() {
    return [
      SubjectProgress(name: 'Physics', icon: '📘', totalChapters: 15),
      SubjectProgress(name: 'Chemistry', icon: '📗', totalChapters: 14),
      SubjectProgress(name: 'Mathematics', icon: '📕', totalChapters: 16),
      SubjectProgress(name: 'Biology', icon: '📙', totalChapters: 18),
      SubjectProgress(name: 'English', icon: '📓', totalChapters: 10),
      SubjectProgress(name: 'Computer Science', icon: '💻', totalChapters: 12),
    ];
  }

  Future<void> updateProgress(String subjectName, {int? completedChapters, double? avgScore}) async {
    final idx = _subjects.indexWhere((s) => s.name == subjectName);
    if (idx != -1) {
      if (completedChapters != null) _subjects[idx].completedChapters = completedChapters;
      if (avgScore != null) _subjects[idx].avgScore = avgScore;
      _subjects[idx].lastStudied = DateTime.now();
      await save();
    }
  }

  Future<void> incrementChapter(String subjectName) async {
    final idx = _subjects.indexWhere((s) => s.name == subjectName);
    if (idx != -1 && _subjects[idx].completedChapters < _subjects[idx].totalChapters) {
      _subjects[idx].completedChapters++;
      _subjects[idx].lastStudied = DateTime.now();
      await save();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _subjects.map((s) => s.toJson()).toList();
    await prefs.setString('subject_progress', jsonEncode(json));
  }
}
