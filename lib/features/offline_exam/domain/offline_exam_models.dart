import 'dart:convert';

/// A compact, fully offline exam paper. Question shape is kept tiny so a
/// paper fits inside Bluetooth MTU-chunked transfers as well as HTTP.
class OfflineExamPaper {
  final String id;
  final String title;
  final int durationMinutes;
  final List<OfflineExamQuestion> questions;

  const OfflineExamPaper({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.questions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationMinutes': durationMinutes,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory OfflineExamPaper.fromJson(Map<String, dynamic> json) {
    return OfflineExamPaper(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Offline exam',
      durationMinutes: json['durationMinutes'] as int? ?? 10,
      questions: (json['questions'] as List? ?? [])
          .map((q) => OfflineExamQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  static OfflineExamPaper? decode(String raw) {
    try {
      return OfflineExamPaper.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  /// The student-facing copy: correct indexes stripped.
  Map<String, dynamic> toStudentJson() => {
        'id': id,
        'title': title,
        'durationMinutes': durationMinutes,
        'questions': questions
            .map((q) => {'q': q.question, 'opts': q.options})
            .toList(),
      };
}

class OfflineExamQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const OfflineExamQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  Map<String, dynamic> toJson() =>
      {'q': question, 'opts': options, 'i': correctIndex};

  factory OfflineExamQuestion.fromJson(Map<String, dynamic> json) {
    return OfflineExamQuestion(
      question: json['q'] as String? ?? '',
      options: (json['opts'] as List? ?? []).map((o) => o.toString()).toList(),
      correctIndex: json['i'] as int? ?? 0,
    );
  }
}

/// A single completed attempt, kept on the student's device and on the
/// teacher's server.
class OfflineExamResult {
  final String studentName;
  final List<int?> answers;
  final int score;
  final int total;
  final DateTime submittedAt;

  const OfflineExamResult({
    required this.studentName,
    required this.answers,
    required this.score,
    required this.total,
    required this.submittedAt,
  });

  int get percent => total == 0 ? 0 : (score * 100 / total).round();

  Map<String, dynamic> toJson() => {
        'studentName': studentName,
        'answers': answers.map((a) => a).toList(),
        'score': score,
        'total': total,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory OfflineExamResult.fromJson(Map<String, dynamic> json) {
    return OfflineExamResult(
      studentName: json['studentName'] as String? ?? 'Student',
      answers: (json['answers'] as List? ?? [])
          .map((a) => a as int?)
          .toList(),
      score: json['score'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      submittedAt:
          DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
