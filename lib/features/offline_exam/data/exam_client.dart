import 'dart:convert';
import 'dart:io';

import 'package:nexus_edu/features/offline_exam/domain/offline_exam_models.dart';

/// Student-side client for the hotspot server running on the teacher's phone.
class OfflineExamClient {
  OfflineExamClient({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  Uri _uri(String host, int port, String path) =>
      Uri(scheme: 'http', host: host, port: port, path: path);

  Future<OfflineExamPaper?> fetchPaper(String host, int port) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      try {
        final request = await client.getUrl(_uri(host, port, '/paper'));
        final response = await request.close().timeout(timeout);
        final body = await utf8.decodeStream(response).timeout(timeout);
        if (response.statusCode != HttpStatus.ok) return null;
        return OfflineExamPaper.decode(body);
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  /// Returns (score, total) or null on failure.
  Future<(int, int)?> submit(
    String host,
    int port,
    String name,
    List<int?> answers,
  ) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      try {
        final request =
            await client.postUrl(_uri(host, port, '/submit'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'name': name, 'answers': answers}));
        final response = await request.close().timeout(timeout);
        final body = await utf8.decodeStream(response).timeout(timeout);
        if (response.statusCode != HttpStatus.ok) return null;
        final payload = Map<String, dynamic>.from(jsonDecode(body));
        return (payload['score'] as int? ?? 0, payload['total'] as int? ?? 0);
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }
}
