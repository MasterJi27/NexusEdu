import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class YoutubeDiscoveryService {
  static const String _apiKeyPrefsKey = 'youtube_api_key';
  static String? _apiKey;

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.googleapis.com/youtube/v3',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = (prefs.getString(_apiKeyPrefsKey) ?? dotenv.env['YOUTUBE_API_KEY'])
        ?.trim();
  }

  static Future<void> saveApiKey(String key) async {
    final trimmedKey = key.trim();
    _apiKey = trimmedKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, trimmedKey);
  }

  static String? get apiKey => _apiKey;

  static bool get hasApiKey {
    final key = _apiKey?.trim();
    return key != null && key.isNotEmpty && key != 'your_youtube_api_key_here';
  }

  static Future<List<LearningShort>> searchEducationalShorts({
    required String query,
    String? className,
    String? subject,
    String? topic,
  }) async {
    final key = _apiKey?.trim();
    if (key == null || key.isEmpty || key == 'your_youtube_api_key_here') {
      return const [];
    }

    final queryParts = <String>[];
    if (className != null) queryParts.add(className);
    if (subject != null && subject != 'All') queryParts.add(subject);
    if (topic != null && topic != 'All') queryParts.add(topic);
    queryParts.addAll([query, 'education shorts']);
    final scopedQuery = queryParts.join(' ');

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search',
        queryParameters: {
          'part': 'snippet',
          'type': 'video',
          'videoDuration': 'short',
          'videoEmbeddable': 'true',
          'safeSearch': 'strict',
          'maxResults': 8,
          'q': scopedQuery,
          'key': key,
        },
      );

      final items = response.data?['items'];
      if (items is! List) return const [];

      return items
          .map((item) {
            final id = item['id'];
            final snippet = item['snippet'];
            final videoId = id is Map ? id['videoId']?.toString() : null;
            final title = snippet is Map ? snippet['title']?.toString() : null;
            final channel = snippet is Map
                ? snippet['channelTitle']?.toString()
                : null;
            if (videoId == null || title == null) return null;

            return LearningShort(
              videoId: videoId,
              title: title,
              creator: channel == null ? '@YouTube' : '@$channel',
              className: className ?? 'Guest',
              subject: subject ?? 'Topic Search',
              topic: topic ?? query,
              takeaway:
                  'Discovered from YouTube for "$scopedQuery". Watch, then save only if it matches the syllabus point.',
              outcomes: const [
                'Watch the explanation',
                'Compare it with your syllabus',
                'Ask the tutor if any step is unclear',
              ],
              isApiResult: true,
            );
          })
          .whereType<LearningShort>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
