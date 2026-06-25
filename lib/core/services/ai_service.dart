import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static String? _apiKey;
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'nvidia/nemotron-3-ultra-550b-a55b:free';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('gemini_api_key') ?? dotenv.env['GEMINI_API_KEY'];
    _apiKey = _apiKey?.trim();
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedKey = key.trim();
    await prefs.setString('gemini_api_key', trimmedKey);
    _apiKey = trimmedKey;
  }

  static String? get apiKey => _apiKey;

  static bool get _isReady => _apiKey != null && _apiKey!.isNotEmpty;
  static String get _noKeyError => 'API Key not configured.';

  static Future<String> _chat(String prompt, {String systemPrompt = ''}) async {
    if (!_isReady) return _noKeyError;
    try {
      final messages = <Map<String, String>>[];
      if (systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://nexusedu.app',
          'X-Title': 'NexusEdu',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().isNotEmpty) {
          return content.toString();
        }
      }
      return 'Failed to get response. Please try again.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  static Future<String> generateSmartNotes(String topic) async {
    return _chat(
      'Generate highly structured, beautiful markdown study notes for the topic: "$topic". '
      'Include headers, bullet points, and key concepts.',
      systemPrompt: 'You are a study material creator. Create well-organized notes.',
    );
  }

  static Future<String> sendMessageToTutor(String message) async {
    return _chat(
      message,
      systemPrompt: 'You are Nexus, a friendly and intelligent AI Tutor for Indian students. '
          'IMPORTANT RULES:\n'
          '1. ALWAYS respond in clear English.\n'
          '2. NEVER respond in Hinglish or mixed language.\n'
          '3. Be helpful, encouraging, and concise.\n'
          '4. If the student asks to explain a topic, explain it clearly with examples.\n'
          '5. Use simple language a 15-17 year old student can understand.\n'
          '6. Format responses with proper paragraphs and bullet points.\n'
          '7. Never say "topic bataya nahi" - if the topic is unclear, ask politely in English.',
    );
  }

  static Stream<String> sendMessageStreamToTutor(String message) async* {
    if (!_isReady) {
      yield _noKeyError;
      return;
    }
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://nexusedu.app',
          'X-Title': 'NexusEdu',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': 'You are Nexus, a friendly AI Tutor for Indian students. '
                'ALWAYS respond in clear English. Be helpful, encouraging, and concise. '
                'Use simple language. Format responses properly.'},
            {'role': 'user', 'content': message},
          ],
          'max_tokens': 2048,
          'temperature': 0.7,
          'stream': true,
        }),
      );

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final data = jsonDecode(line.substring(6));
              final content = data['choices']?[0]?['delta']?['content'];
              if (content != null) yield content;
            } catch (_) {}
          }
        }
      } else {
        yield 'Failed to get response.';
      }
    } catch (e) {
      yield 'Connection error: $e';
    }
  }

  static Future<String> roastEssay(String essayText) async {
    return _chat(
      'Roast this essay with brutally honest, slightly sarcastic but helpful feedback. '
      'Critique grammar, flow, logic. End with actionable advice.\n\n$essayText',
      systemPrompt: 'You are "Essay Roaster", a brutally honest but helpful AI writing critic.',
    );
  }

  static void resetSocraticSession() {}

  static Future<String> sendMessageToSocraticTutor(String message) async {
    return _chat(
      message,
      systemPrompt: 'You are a Socratic Math Tutor. Guide students to find answers themselves. '
          'Never give direct answers immediately. Ask leading questions, validate steps, '
          'and hint at techniques. Use clear text and markdown.',
    );
  }

  static Future<String> solveMathProblem(String problem) async {
    return _chat(
      'Solve this math problem step by step: $problem\nShow all working clearly.',
      systemPrompt: 'You are a math tutor. Solve problems step by step with clear explanations.',
    );
  }

  static Future<String> generateYoutubeSummary(String url) async {
    return _chat(
      'Summarize this YouTube video: $url\n'
      'Generate a 3-bullet summary plus a 1-question MCQ with 3 options.',
      systemPrompt: 'You are a YouTube Video Summarizer.',
    );
  }

  static Future<String> generateCurriculum(String subject) async {
    return _chat(
      'For the subject "$subject", generate a JSON array of 8 learning topics. '
      'Each topic must have: "title" (string), "summary" (string, 2 sentences), '
      '"difficulty" (Beginner/Intermediate/Advanced), "estimatedMinutes" (int), '
      '"emerging" (bool). Raw JSON only, no markdown.',
      systemPrompt: 'You are a self-assembling curriculum AI.',
    );
  }

  static Future<String> generateCurriculumContent(String topic) async {
    return _chat(
      'Generate comprehensive study content for "$topic". '
      'Include: key concepts, real-world applications, and 3 quiz questions with answers. '
      'Format in markdown.',
      systemPrompt: 'You are a study content generator.',
    );
  }

  static Future<Map<String, String>> swarmTeach(
    String concept, String strategy, String persona,
  ) async {
    final lesson = await _chat(
      'Teach the concept "$concept" in exactly 4 sentences using a $strategy strategy. '
      'Be concise and distinctive.',
      systemPrompt: 'You are Agent "$persona", a teaching AI.',
    );
    final quiz = await _chat(
      'Based on "$concept", generate exactly one MCQ with 4 options (A-D). '
      'Format: Question?\nA) ...\nB) ...\nC) ...\nD) ...\nAnswer: LETTER',
      systemPrompt: 'You are a quiz generator.',
    );
    return {'lesson': lesson, 'quiz': quiz};
  }

  static Future<String> generateFlashcards(String topic) async {
    return _chat(
      'Generate 10 flashcards for "$topic". '
      'Return a JSON array of objects with "front" (question) and "back" (answer). '
      'Raw JSON only, no markdown.',
      systemPrompt: 'You are a flashcard creator.',
    );
  }

  static Future<String> analyzeImage(List<int> imageBytes, String prompt) async {
    return _chat(
      'Analyze this image and answer: $prompt\n'
      'Describe what you see and provide relevant information.',
      systemPrompt: 'You are an image analysis AI. Describe images in detail.',
    );
  }

  static Future<List<Map<String, dynamic>>> generateMemoryPalace(String topic) async {
    final response = await _chat(
      'Generate a memory palace for "$topic". Return a JSON list of 4 items. '
      'Each item: "title" (string), "iconName" (string: security/handshake/public/flag/science/history/auto_stories/star/rocket_launch/psychology), '
      '"colorName" (string: red/blue/green/orange/purple/teal), '
      '"story" (string, vivid visual story). Raw JSON only.',
      systemPrompt: 'You are a memory palace generator.',
    );
    try {
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
        jsonStr = lines.join('\n').trim();
      }
      final decoded = json.decode(jsonStr);
      if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
    } catch (_) {}
    return [];
  }
}
