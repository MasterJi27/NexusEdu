import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// Typed client for the backend's `/api/azure-ai` endpoints (Azure Speech,
/// Translator, Document Intelligence, Content Safety, Language, Vision).
/// All calls require a signed-in user (JWT is attached automatically).
class AzureAiService {
  AzureAiService._();

  static const String _base = '/api/azure-ai';

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${SecureApiService.baseUrl}$_base$path')
        .replace(queryParameters: query);
  }

  // -------------------------------------------------------------------------
  // Speech
  // -------------------------------------------------------------------------

  /// Hindi/Indian-language neural text-to-speech. Returns MP3 bytes.
  static Future<Uint8List?> textToSpeech(
    String text, {
    String voice = 'hi-IN-SwaraNeural',
    String rate = '+0%',
  }) async {
    if (SecureApiService().token == null) return null;
    try {
      final response = await SecureApiService()
          .sendAuthenticated(
            'POST',
            '$_base/speech/tts',
            body: {'text': text, 'voice': voice, 'rate': rate},
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Speech-to-text. [wavBytes] must be a 16-bit PCM WAV (8k-48k Hz).
  /// Returns recognized text ('' on failure).
  static Future<String> speechToText(
    Uint8List wavBytes, {
    String language = 'en-US',
  }) async {
    final token = SecureApiService().token;
    if (token == null) return '';
    try {
      final response = await http
          .post(
            _uri('/speech/stt', {'language': language}),
            headers: {
              'Content-Type': 'audio/wav',
              'Authorization': 'Bearer $token',
            },
            body: wavBytes,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['text'] ?? '') as String;
      }
    } catch (_) {}
    return '';
  }

  /// Pronunciation assessment. Returns scores (null on failure) with
  /// per-word accuracy + error types.
  static Future<PronunciationResult?> pronunciationAssessment(
    Uint8List wavBytes,
    String referenceText, {
    String language = 'en-US',
  }) async {
    final token = SecureApiService().token;
    if (token == null) return null;
    try {
      final response = await http
          .post(
            _uri('/speech/pronunciation', {
              'language': language,
              'referenceText': referenceText,
            }),
            headers: {
              'Content-Type': 'audio/wav',
              'Authorization': 'Bearer $token',
            },
            body: wavBytes,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final words = (data['words'] as List<dynamic>? ?? const [])
          .map<PronunciationWord>((w) {
        final m = w as Map<String, dynamic>;
        return PronunciationWord(
          word: m['word'] as String? ?? '',
          accuracy: (m['accuracy'] as num?)?.toDouble(),
          errorType: m['errorType'] as String?,
        );
      }).toList();
      return PronunciationResult(
        text: data['text'] as String? ?? '',
        accuracy: (data['accuracy'] as num?)?.toDouble(),
        fluency: (data['fluency'] as num?)?.toDouble(),
        completeness: (data['completeness'] as num?)?.toDouble(),
        pronunciation: (data['pronunciation'] as num?)?.toDouble(),
        words: words,
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Translation
  // -------------------------------------------------------------------------

  /// Translates [text] via Azure Translator. Returns translated text, or the
  /// original text on failure (safe fallback for chat UIs).
  static Future<String> translate(
    String text, {
    required String to,
    String? from,
  }) async {
    if (SecureApiService().token == null) return text;
    try {
      final response = await SecureApiService()
          .sendAuthenticated(
            'POST',
            '$_base/translate',
            body: {
              'text': text,
              'to': to,
              if (from != null) 'from': from,
            },
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final translated = data['translatedText'] as String? ?? '';
        if (translated.isNotEmpty) return translated;
      }    } catch (_) {}
    return text;
  }

  // -------------------------------------------------------------------------
  // Content safety
  // -------------------------------------------------------------------------

  /// Content moderation. Returns severity per category for flagged content.
  static Future<ModerationResult?> moderateText(String text) async {
    if (SecureApiService().token == null) return null;
    try {
      final response = await SecureApiService()
          .sendAuthenticated('POST', '$_base/moderate', body: {'text': text})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final categories = (data['categories'] as List<dynamic>? ?? const [])
          .map<ModerationCategory>((c) {
        final m = c as Map<String, dynamic>;
        return ModerationCategory(
          category: m['category'] as String? ?? '',
          severity: (m['severity'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      return ModerationResult(
        flagged: data['flagged'] as bool? ?? false,
        action: data['action'] as String? ?? 'allow',
        categories: categories,
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Document Intelligence (OCR)
  // -------------------------------------------------------------------------

  /// OCR for handwritten/printed notes. Returns extracted text ('' on failure).
  static Future<String> ocrImage(Uint8List imageBytes) async {
    final token = SecureApiService().token;
    if (token == null) return '';
    try {
      final response = await http
          .post(
            _uri('/ocr'),
            headers: {
              'Content-Type': 'image/jpeg',
              'Authorization': 'Bearer $token',
            },
            body: imageBytes,
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['text'] ?? '') as String;
      }
    } catch (_) {}
    return '';
  }

  // -------------------------------------------------------------------------
  // Language
  // -------------------------------------------------------------------------

  /// Sentiment analysis. Returns the label (positive/neutral/negative) or
  /// null on failure.
  static Future<String?> sentiment(String text) async {
    if (SecureApiService().token == null) return null;
    try {
      final response = await SecureApiService()
          .sendAuthenticated('POST', '$_base/language/sentiment', body: {'text': text})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['sentiment'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Extracts key phrases from [text].
  static Future<List<String>> keyPhrases(String text) async {
    if (SecureApiService().token == null) return const [];
    try {
      final response = await SecureApiService()
          .sendAuthenticated('POST', '$_base/language/keyphrases', body: {'text': text})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['keyPhrases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Vision analysis: caption + tags for an image.
  static Future<VisionResult?> visionAnalyze(Uint8List imageBytes) async {
    final token = SecureApiService().token;
    if (token == null) return null;
    try {
      final response = await http
          .post(
            _uri('/vision/analyze'),
            headers: {
              'Content-Type': 'image/jpeg',
              'Authorization': 'Bearer $token',
            },
            body: imageBytes,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tags = (data['tags'] as List<dynamic>? ?? const [])
          .map<String>((t) => (t as Map<String, dynamic>)['name'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      return VisionResult(
        caption: data['caption'] as String?,
        captionConfidence: (data['captionConfidence'] as num?)?.toDouble(),
        tags: tags,
      );
    } catch (_) {
      return null;
    }
  }

  /// Backend health for all six Azure AI services.
  static Future<Map<String, String>> health() async {
    if (SecureApiService().token == null) return const {};
    try {
      final response = await SecureApiService()
          .sendAuthenticated('GET', '$_base/health')
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const {};
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }
}

class PronunciationWord {
  const PronunciationWord({
    required this.word,
    this.accuracy,
    this.errorType,
  });

  final String word;
  final double? accuracy;
  final String? errorType;
}

class PronunciationResult {
  const PronunciationResult({
    required this.text,
    this.accuracy,
    this.fluency,
    this.completeness,
    this.pronunciation,
    required this.words,
  });

  final String text;
  final double? accuracy;
  final double? fluency;
  final double? completeness;
  final double? pronunciation;
  final List<PronunciationWord> words;

  bool get hasScores => accuracy != null;
}

class ModerationCategory {
  const ModerationCategory({required this.category, required this.severity});

  final String category;
  final int severity;
}

class ModerationResult {
  const ModerationResult({
    required this.flagged,
    required this.action,
    required this.categories,
  });

  final bool flagged;
  final String action;
  final List<ModerationCategory> categories;
}

class VisionResult {
  const VisionResult({this.caption, this.captionConfidence, required this.tags});

  final String? caption;
  final double? captionConfidence;
  final List<String> tags;
}
