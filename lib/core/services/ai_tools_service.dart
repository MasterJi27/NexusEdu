import 'dart:convert';
import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Client for the backend AI feature endpoints that return structured JSON:
/// the data agent, quiz generator and assignment grader. All calls are
/// proxied through the backend, so no AI provider key ever lives in the app.
class AiToolsService {
  static final AiToolsService _instance = AiToolsService._();
  factory AiToolsService() => _instance;
  AiToolsService._();

  static const _timeout = Duration(seconds: 60);

  static const offlineMessage =
      "You're offline. AI features need an internet connection — reconnect and try again.";

  /// Hard AI gate shared by every method: no backend, no AI.
  static Future<bool> _online() => ConnectivityService.instance.check();

  /// Data agent chat. [history] is the prior [{role, content}] exchange
  /// (role: user/assistant); the backend adds the system prompt and its
  /// tools itself. Returns the agent's reply text.
  Future<String> agentChat(
    List<Map<String, String>> history,
    String message,
  ) async {
    final token = SecureApiService().token;
    if (token == null) {
      return 'Please sign in to use the study assistant.';
    }
    if (!await _online()) return offlineMessage;
    try {
      final messages = [
        ...history.map((m) => {
              'role': m['role'] ?? 'user',
              'content': m['text'] ?? '',
            }),
        {'role': 'user', 'content': message},
      ];
      final response = await SecureApiService().sendAuthenticated(
        'POST',
        '/api/ai/agent',
        body: {'messages': messages},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString().trim();
        }
      }
      final err = _errorFrom(response.body);
      if (err.isNotEmpty) return err;
      return 'The assistant could not answer right now. Please try again.';
    } catch (_) {
      return 'Connection failed. Please check your internet.';
    }
  }

  /// Generates a multiple-choice quiz. Returns a list of question maps with
  /// keys question/options/correctIndex/explanation, or null on failure.
  Future<List<Map<String, dynamic>>?> generateQuiz({
    required String topic,
    required String subject,
    String? gradeLevel,
    int count = 5,
  }) async {
    final token = SecureApiService().token;
    if (token == null) return null;
    if (!await _online()) return null;
    try {
      final response = await SecureApiService().sendAuthenticated(
        'POST',
        '/api/ai/generate-quiz',
        body: {
          'topic': topic,
          'subject': subject,
          if (gradeLevel != null && gradeLevel.isNotEmpty)
            'gradeLevel': gradeLevel,
          'count': count,
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['questions'];
        if (raw is List) {
          return raw
              .map((q) => Map<String, dynamic>.from(q as Map))
              .where((q) => q['question'] != null && q['options'] is List)
              .toList();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Grades a student's assignment. Returns the rubric map
  /// (score/maxScore/overallFeedback/strengths/weaknesses/grammarIssues),
  /// or null on failure.
  Future<Map<String, dynamic>?> gradeAssignment({
    String? title,
    required String content,
    int maxScore = 10,
  }) async {
    final token = SecureApiService().token;
    if (token == null) return null;
    if (!await _online()) return null;
    try {
      final response = await SecureApiService().sendAuthenticated(
        'POST',
        '/api/ai/grade-assignment',
        body: {
          if (title != null && title.isNotEmpty) 'title': title,
          'content': content,
          'maxScore': maxScore,
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['score'] is num) return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _errorFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is String) return err;
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
      }
    } catch (_) {}
    return '';
  }
}
