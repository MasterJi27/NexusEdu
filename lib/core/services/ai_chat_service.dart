import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Thrown by [AiChatService.chat] when the caller has no auth token. Distinct
/// from a generic failure so callers can show a "Sign in" action instead of
/// "Retry" — retrying does nothing for a guest.
class AiSignInRequiredException implements Exception {
  const AiSignInRequiredException();
  @override
  String toString() => 'Sign in to use AI features.';
}

/// All AI features call the NexusEdu backend, which holds the AI provider
/// keys server-side. No client-side AI provider key is used.
class AiChatService {
  static final AiChatService _instance = AiChatService._();
  factory AiChatService() => _instance;
  AiChatService._();

  static const offlineMessage =
      "You're offline. AI features need an internet connection — reconnect and try again.";

  Future<String> chat(String prompt, {String systemPrompt = ''}) async {
    final sanitized = _sanitizeInput(prompt);
    if (sanitized == null) {
      return 'Your message was flagged for safety. Please rephrase your question.';
    }

    // Hard AI gate: never pretend to work offline. The backend holds the AI
    // provider keys, so no backend, no AI — the canned fallback below is
    // reserved for online-but-server-error cases.
    if (!await ConnectivityService.instance.check()) {
      return offlineMessage;
    }

    final messages = <Map<String, String>>[];
    if (systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': sanitized});

    if (SecureApiService().token == null) {
      throw const AiSignInRequiredException();
    }
    try {
      final response = await SecureApiService().sendAuthenticated(
        'POST',
        '/api/ai/chat',
        body: {
          'messages': messages,
          'max_tokens': 1024,
          'temperature': 0.7,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().isNotEmpty) {
          return content.toString();
        }
      }
      // Used to fall back to canned prose indistinguishable from a real
      // answer here (DESIGN.md §08 calls this out as worse than an error) —
      // callers must now catch this and show a real error state.
      throw Exception("Couldn't reach the server. Check your connection and try again.");
    } on TimeoutException {
      return offlineMessage;
    } on http.ClientException {
      // The connection dropped mid-request (covers SocketException, which
      // package:http wraps) — same verdict as the pre-flight gate.
      return offlineMessage;
    }
  }

  /// For callers that need a structured (JSON) reply back, not prose.
  /// Sends [prompt] to the model verbatim — unlike [chat]'s sibling
  /// convenience methods (`generateNotes`, `generateQuiz`, etc.), it does not
  /// wrap the argument in a hardcoded template, since the caller's prompt
  /// already specifies the exact JSON shape it expects. Strips a
  /// ```json ... ``` fence if the model wraps its reply in one.
  Future<String> generateJson(String prompt, {String systemPrompt = ''}) async {
    final raw = await chat(
      prompt,
      systemPrompt: systemPrompt.isNotEmpty
          ? systemPrompt
          : 'Respond with ONLY valid JSON. No markdown code fences, no commentary, no explanation.',
    );
    return _stripJsonFences(raw);
  }

  String _stripJsonFences(String text) {
    final trimmed = text.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
    return fenced?.group(1)?.trim() ?? trimmed;
  }

  Future<String> solveDoubt(String question, String subject) async {
    return chat(
      question,
      systemPrompt: 'You are a helpful tutor for $subject. '
          'ALWAYS respond in clear English. NEVER use Hinglish. '
          'Explain step by step in simple language. '
          'Use examples where possible. '
          'Keep the explanation clear and concise.',
    );
  }

  Future<String> explainConcept(String concept, String subject) async {
    return chat(
      'Explain the concept of $concept in $subject in detail. '
      'Use real-life examples and analogies. '
      'Make it easy to understand for a student.',
      systemPrompt: 'You are an expert $subject teacher for Indian students. '
          'ALWAYS respond in clear English. NEVER use Hinglish. '
          'Explain concepts in a simple, engaging way.',
    );
  }

  Future<String> generateQuiz(String topic, String subject, {int count = 5}) async {
    return chat(
      'Generate $count quiz questions on $topic in $subject. '
      'Each question should have 4 options (A, B, C, D) with the correct answer marked. '
      'Format: Question, Options, Correct Answer, Brief Explanation.',
      systemPrompt: 'You are a quiz generator for $subject. '
          'Create clear, educational questions.',
    );
  }

  Future<String> generateNotes(String topic, String subject) async {
    return chat(
      'Create comprehensive study notes on $topic in $subject. '
      'Include key points, formulas, diagrams descriptions, and summary. '
      'Format with headings and bullet points.',
      systemPrompt: 'You are a study material creator. '
          'Create well-organized, easy to revise notes.',
    );
  }

  Future<String> solveMath(String problem) async {
    return chat(
      'Solve this math problem step by step: $problem '
      'Show all working clearly.',
      systemPrompt: 'You are a math tutor. '
          'Solve problems step by step with clear explanations.',
    );
  }

  Future<String> generateFlashcards(String topic, String subject, {int count = 10}) async {
    final subjectPart = subject.isNotEmpty ? ' in $subject' : '';
    return generateJson(
      'Create $count flashcards on $topic$subjectPart. '
      'Return a JSON array of objects, each with a "front" (question/concept) '
      'and "back" (answer/definition) string. Make them concise and exam-focused.',
      systemPrompt: 'You are a flashcard creator for exam preparation. '
          'Respond with ONLY a valid JSON array, no markdown code fences, no commentary.',
    );
  }

  Future<String> evaluateEssay(String essay, String topic) async {
    return chat(
      'Evaluate this essay on "$topic":\n\n$essay\n\n'
      'Provide: 1) Score out of 10, 2) Strengths, 3) Weaknesses, '
      '4) Suggestions for improvement, 5) Grammar issues if any.',
      systemPrompt: 'You are an essay evaluator. '
          'Provide constructive, detailed feedback.',
    );
  }

  Future<String> generateStudyPlan(String exam, int daysLeft, List<String> subjects) async {
    return chat(
      'Create a $daysLeft-day study plan for $exam. '
      'Subjects: ${subjects.join(", ")}. '
      'Include daily tasks, revision schedule, and break times.',
      systemPrompt: 'You are a study planner. '
          'Create realistic, effective study schedules.',
    );
  }

  Future<String> translate(String text, String targetLanguage) async {
    return chat(
      'Translate the following to $targetLanguage:\n$text',
      systemPrompt: 'You are a translator. '
          'Provide accurate, natural translations.',
    );
  }

  String? _sanitizeInput(String input) {
    final lower = input.toLowerCase();

    final blockedPatterns = [
      'ignore previous instructions',
      'ignore all instructions',
      'ignore above instructions',
      'ignore the above',
      'ignore the previous',
      'ignore your instructions',
      'disregard previous',
      'disregard all',
      'forget everything',
      'forget your instructions',
      'you are now',
      'act as if',
      'pretend you are',
      'new instructions:',
      'system prompt:',
      'reveal system prompt',
      'show system prompt',
      'what are your instructions',
      'override safety',
      'bypass filters',
      'jailbreak',
      'developer mode',
      'sudo',
      'admin mode',
    ];

    for (final pattern in blockedPatterns) {
      if (lower.contains(pattern)) return null;
    }

    final cleanInput = input.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s.,!?;()+*/=<>-]', unicode: true),
      '',
    );
    if (cleanInput.length > 2000) {
      return cleanInput.substring(0, 2000);
    }

    return cleanInput;
  }
}
