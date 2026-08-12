import 'package:nexus_edu/core/services/ai_chat_service.dart';

/// AI helpers for feature screens.
///
/// Thin adapter over [AiChatService], which calls the NexusEdu backend
/// (`/api/ai/chat`). The backend holds the AI provider keys server-side, so
/// there is no client-side API key and no "API Key not configured." path.
/// The class name and static signatures are kept for the feature screens
/// that historically called this service directly.
class AiService {
  static Future<String> chatRaw(String prompt, {String systemPrompt = ''}) =>
      AiChatService().chat(prompt, systemPrompt: systemPrompt);

  static Future<String> generateSmartNotes(String topic) =>
      AiChatService().generateNotes(topic, '');

  static Future<String> sendMessageToTutor(String message) =>
      AiChatService().chat(
        message,
        systemPrompt: 'You are Nexus, a friendly and intelligent AI Tutor for Indian students. '
            'IMPORTANT RULES:\n'
            '1. ALWAYS respond in clear English.\n'
            '2. NEVER respond in Hinglish or mixed language.\n'
            '3. Be helpful, encouraging, and concise.\n'
            '4. If the student asks to explain a topic, explain it clearly with examples.\n'
            '5. Use simple language a 15-17 year old student can understand.\n'
            '6. FORMAT YOUR ANSWER IN CLEAN MARKDOWN: a short bold heading (##) when useful, '
            'short paragraphs, and bullet lists for steps or points. Keep it scannable.\n'
            '7. NEVER use LaTeX or backslash math notation — write math as '
            'plain text (e.g. "F = m × a", "x² + 2x + 1 = 0").\n'
            '8. Do not overuse bold and never use emojis.\n'
            '9. Never say "topic bataya nahi" - if the topic is unclear, ask politely in English.',
      );

  static Stream<String> sendMessageStreamToTutor(String message) async* {
    yield await sendMessageToTutor(message);
  }

  static Future<String> generateCurriculumContent(String topic) =>
      AiChatService().chat(
        'Generate comprehensive study content for "$topic". '
        'Include: key concepts, real-world applications, and 3 quiz questions with answers. '
        'Format in markdown.',
        systemPrompt: 'You are a study content generator.',
      );

  static Future<String> generateYoutubeSummary(String url) =>
      AiChatService().chat(
        'Summarize this YouTube video: $url\n'
        'Generate a 3-bullet summary plus a 1-question MCQ with 3 options.',
        systemPrompt: 'You are a YouTube Video Summarizer.',
      );

  static Future<String> generateFlashcards(String topic) =>
      AiChatService().generateFlashcards(topic, '', count: 10);

  /// For screens that send their own full prompt and expect JSON back (e.g.
  /// a schema description for a generated quiz or study plan) — unlike
  /// [generateCurriculumContent], this does not wrap [prompt] in a hardcoded
  /// "generate study content... format in markdown" template.
  static Future<String> generateStructured(String prompt) =>
      AiChatService().generateJson(prompt);
}
