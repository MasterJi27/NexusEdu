import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'dart:convert';

class AiService {
  static String? _apiKey;
  static GenerativeModel? _model;
  static GenerativeModel? _visionModel;
  static ChatSession? _chatSession;
  static ChatSession? _socraticSession;

  static void _initModels() {
    if (_apiKey != null &&
        _apiKey!.isNotEmpty &&
        _apiKey != 'your_api_key_here') {
      try {
        _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey!);
        _visionModel = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey!);
        _chatSession = _model!.startChat();
        _socraticSession = null;
      } catch (e) {
        _model = null;
        _visionModel = null;
        _chatSession = null;
        _socraticSession = null;
      }
    } else {
      _model = null;
      _visionModel = null;
      _chatSession = null;
      _socraticSession = null;
    }
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('gemini_api_key') ?? dotenv.env['GEMINI_API_KEY'];
    _apiKey = _apiKey?.trim();
    _initModels();
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedKey = key.trim();
    await prefs.setString('gemini_api_key', trimmedKey);
    _apiKey = trimmedKey;
    _initModels();
  }

  static String? get apiKey => _apiKey;

  static bool get _isReady => _model != null;
  static String get _noKeyError =>
      'Gemini API Key not set. Go to Profile to set it.';

  static Future<String> generateSmartNotes(String topic) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "Generate highly structured, beautiful markdown study notes for the topic: '$topic'. Include headers, bullet points, and key concepts.",
        ),
      ]);
      return response.text ?? 'Failed to generate notes.';
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Future<String> sendMessageToTutor(String message) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _chatSession!.sendMessage(
        Content.text(
          "You are Nexus, an elite, highly encouraging, and intelligent AI Tutor. Keep responses concise, conversational, and helpful. Student says: $message",
        ),
      );
      return response.text ?? "I'm having trouble thinking right now.";
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Stream<String> sendMessageStreamToTutor(String message) async* {
    if (!_isReady) {
      yield _noKeyError;
      return;
    }
    try {
      final responseStream = _chatSession!.sendMessageStream(
        Content.text(
          "You are Nexus, an elite, highly encouraging, and intelligent AI Tutor. Keep responses concise, conversational, and helpful. Student says: $message",
        ),
      );
      await for (final chunk in responseStream) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield '\n\nAPI Error: $e';
    }
  }

  static Future<String> roastEssay(String essayText) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "You are 'Essay Roaster', a brutally honest, slightly sarcastic, but helpful AI writing critic. Roast the grammar, flow, and logic, but end with actionable advice. Text:\n\n$essayText",
        ),
      ]);
      return response.text ?? "Wow, that was so bad I have no words.";
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static void resetSocraticSession() {
    _socraticSession = null;
  }

  static Future<String> sendMessageToSocraticTutor(String message) async {
    if (!_isReady) return _noKeyError;
    try {
      _socraticSession ??= _model!.startChat(
        history: [
          Content.text(
            "Hello. You are a Socratic Math Tutor. Your goal is to guide students to find mathematical answers themselves. Never give the direct final answer immediately. Ask leading questions, validate their steps, and hint at standard techniques (like integration by parts, substitution, etc.). Response in clear text and markdown. Confirm you understand.",
          ),
          Content.model([
            TextPart(
              "Understood. I am ready to guide students using the Socratic method. Let's tackle your math problem step-by-step. What problem are we working on today?",
            ),
          ]),
        ],
      );
      final response = await _socraticSession!.sendMessage(
        Content.text(message),
      );
      return response.text ?? "I'm having trouble thinking right now.";
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Future<String> solveMathProblem(String problem) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "You are a Socratic Math Tutor. Student asked: '$problem'. Give step-by-step breakdown using markdown.",
        ),
      ]);
      return response.text ?? 'I could not solve that.';
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Future<String> generateYoutubeSummary(String url) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "You are a YouTube Video Summarizer. User pasted: $url. Generate a 3-bullet summary of a generic 'Introduction to Web Development' video, plus a 1-question MCQ with 3 options.",
        ),
      ]);
      return response.text ?? 'Failed to summarize video.';
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Future<String> generateCurriculum(String subject) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "You are a self-assembling curriculum AI. For the subject '$subject', "
          "generate a JSON array of 8 learning topics. Each topic must have: "
          "\"title\" (string), \"summary\" (string, 2 sentences), "
          "\"difficulty\" (string, one of: Beginner/Intermediate/Advanced), "
          "\"estimatedMinutes\" (int), \"emerging\" (bool — true if this is a cutting-edge topic). "
          "Raw JSON only, no markdown, no code fences.",
        ),
      ]);
      return response.text ?? '[]';
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Future<String> generateCurriculumContent(String topic) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "Generate comprehensive study content for the topic '$topic'. "
          "Include: key concepts, real-world applications, and 3 quiz questions with answers. "
          "Format in markdown.",
        ),
      ]);
      return response.text ?? 'Failed to generate content.';
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static Future<Map<String, String>> swarmTeach(
    String concept, String strategy, String persona,
  ) async {
    if (!_isReady) return {'lesson': _noKeyError, 'quiz': ''};
    try {
      final lessonResp = await _model!.generateContent([
        Content.text(
          "You are Agent '$persona', a teaching AI with a $strategy strategy. "
          "Teach the concept '$concept' in exactly 4 sentences using your strategy. "
          "Be concise and distinctive in your approach.",
        ),
      ]);
      final quizResp = await _model!.generateContent([
        Content.text(
          "Based on this explanation of '$concept', generate exactly one MCQ with 4 options (A-D). "
          "Format:\nQuestion?\nA) ...\nB) ...\nC) ...\nD) ...\nAnswer: LETTER",
        ),
      ]);
      return {
        'lesson': lessonResp.text ?? 'No lesson generated.',
        'quiz': quizResp.text ?? 'No quiz generated.',
      };
    } catch (e) {
      return {'lesson': 'API Error: $e', 'quiz': ''};
    }
  }

  static Future<String> generateFlashcards(String topic) async {
    if (!_isReady) return _noKeyError;
    try {
      final response = await _model!.generateContent([
        Content.text(
          "Generate 10 flashcards for the topic: '$topic'. "
          "Return a JSON array of objects. Each object must have exactly two keys: "
          "\"front\" (string, the question/term) and \"back\" (string, the answer/definition). "
          "No markdown, no code fences. Raw JSON only.",
        ),
      ]);
      return response.text ?? '[]';
    } catch (e) {
      return 'API Error: $e';
    }
  }

  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
      if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';
      if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'image/webp';
    }
    return 'image/jpeg';
  }

  static Future<String> analyzeImage(
    Uint8List imageBytes,
    String prompt,
  ) async {
    final mimeType = _detectMimeType(imageBytes);
    GenerativeModel? tryModel;

    for (final model in [_visionModel, _model]) {
      if (model == null) continue;
      tryModel = model;
      try {
        final response = await tryModel.generateContent([
          Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
        ]);
        if (response.text != null) return response.text!;
      } catch (_) {
        continue;
      }
    }

    if (!_isReady) return _noKeyError;
    return 'Image analysis failed: your API key may not support vision models. Go to Profile to update your API key.';
  }

  static Future<List<Map<String, dynamic>>> generateMemoryPalace(
    String topic,
  ) async {
    if (!_isReady) return [];
    try {
      final response = await _model!.generateContent([
        Content.text(
          "Generate a memory palace for the topic: '$topic'. Return a JSON list of 4 items. Each item must have exactly: "
          "\"title\" (string, e.g., \"The Lobby: concept\"), "
          "\"iconName\" (string, one of: \"security\", \"handshake\", \"public\", \"flag\", \"science\", \"history\", \"auto_stories\", \"star\", \"rocket_launch\", \"psychology\"), "
          "\"colorName\" (string, one of: \"red\", \"blue\", \"green\", \"orange\", \"purple\", \"teal\"), "
          "\"story\" (string, a vivid visual story connecting the room and the concept). "
          "Do not include any markdown format tags like ```json. Return raw JSON text only.",
        ),
      ]);

      final text = response.text ?? '';
      String jsonStr = text.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        jsonStr = lines.join('\n').trim();
      }

      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
