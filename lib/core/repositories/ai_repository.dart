import 'package:nexus_edu/core/constants/app_constants.dart';
import 'package:nexus_edu/core/services/ai_chat_service.dart';
import 'package:nexus_edu/core/services/ai_tools_service.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Unified AI facade — all methods return `Result<String>` / `Result<List>`
/// so screens can `switch` on success vs auth vs network vs server.
class AiRepository {
  AiRepository({AiChatService? chat, AiToolsService? tools})
      : _chat = chat ?? AiChatService(),
        _tools = tools ?? AiToolsService();
  final AiChatService _chat;
  final AiToolsService _tools;

  Future<Result<String>> chat(String prompt, {String systemPrompt = ''}) async {
    try {
      final res = await _chat.chat(prompt, systemPrompt: systemPrompt);
      // AiChatService returns offlineMessage as success string for offline —
      // detect it and convert to Failure for typed handling.
      if (res == AppConstants.offlineMessage) {
        return const Failure(AppConstants.offlineMessage, kind: FailureKind.network);
      }
      if (res == AppConstants.aiSafetyMessage) {
        return const Failure(AppConstants.aiSafetyMessage, kind: FailureKind.server);
      }
      return Success(res);
    } on AiSignInRequiredException {
      return const Failure('Please sign in to use AI features.', kind: FailureKind.auth);
    } catch (e) {
      final msg = e.toString().contains(AppConstants.offlineMessage)
          ? AppConstants.offlineMessage
          : (e.toString().isEmpty ? AppConstants.serverUnreachableMessage : e.toString());
      return Failure(msg, error: e, kind: FailureKind.server);
    }
  }

  Future<Result<String>> chatWithImage(
    String message,
    String imageDataUri, {
    String systemPrompt = '',
  }) async {
    try {
      final res = await _chat.chatWithImage(message, imageDataUri, systemPrompt: systemPrompt);
      if (res == AppConstants.offlineMessage) {
        return const Failure(AppConstants.offlineMessage, kind: FailureKind.network);
      }
      return Success(res);
    } on AiSignInRequiredException {
      return const Failure('Please sign in to use AI features.', kind: FailureKind.auth);
    } catch (e) {
      return Failure(e.toString(), error: e, kind: FailureKind.server);
    }
  }

  Future<Result<List<Map<String, dynamic>>>> generateQuiz({
    required String topic,
    required String subject,
    String? gradeLevel,
    int count = 5,
  }) async {
    try {
      final res = await _tools.generateQuiz(
        topic: topic,
        subject: subject,
        gradeLevel: gradeLevel,
        count: count,
      );
      if (res == null) {
        // null = auth/offline/server indistinguishable pre-migration;
        // probe offline first.
        return const Failure('Could not generate quiz. Please try again.', kind: FailureKind.server);
      }
      return Success(res);
    } catch (e) {
      return Failure(e.toString(), error: e);
    }
  }

  Future<Result<Map<String, dynamic>>> gradeAssignment({
    String? title,
    required String content,
    int maxScore = 10,
  }) async {
    try {
      final res = await _tools.gradeAssignment(title: title, content: content, maxScore: maxScore);
      if (res == null) return const Failure('Could not grade assignment.', kind: FailureKind.server);
      return Success(res);
    } catch (e) {
      return Failure(e.toString(), error: e);
    }
  }
}
