import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nexus_edu/features/offline_exam/domain/offline_exam_models.dart';

/// Runs inside the teacher's app. Students on the same WiFi hotspot reach it
/// at `http://<teacherIp>:<port>`.
///
/// Routes:
///  - GET  /health  -> {ok, title}
///  - GET  /paper   -> student-safe paper JSON
///  - POST /submit  -> {name, answers} -> {score, total, percent}
///  - GET  /results -> {results: [...]}
class OfflineExamServer {
  OfflineExamServer({this.port = 8787});

  final int port;
  HttpServer? _server;
  OfflineExamPaper? _paper;
  final List<OfflineExamResult> _results = [];

  bool get isRunning => _server != null;

  /// The port the server actually bound to (useful when port 0 was requested).
  int get boundPort => _server?.port ?? port;

  List<OfflineExamResult> get results => List.unmodifiable(_results);

  Future<void> start(OfflineExamPaper paper) async {
    await stop();
    _paper = paper;
    _results.clear();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final response = request.response;

      if (path == '/health') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'ok': true, 'title': _paper?.title ?? ''}));
      } else if (path == '/paper') {
        if (_paper == null) {
          response.statusCode = HttpStatus.notFound;
          response.write('No paper hosted.');
        } else {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(_paper!.toStudentJson()));
        }
      } else if (path == '/submit' && request.method == 'POST') {
        final body = await utf8.decodeStream(request);
        final payload = Map<String, dynamic>.from(jsonDecode(body));
        final name = (payload['name'] as String? ?? 'Student').trim();
        final answers = (payload['answers'] as List? ?? [])
            .map((a) => a as int?)
            .toList();
        final score = _grade(answers);
        final result = OfflineExamResult(
          studentName: name.isEmpty ? 'Student' : name,
          answers: answers,
          score: score,
          total: _paper?.questions.length ?? answers.length,
          submittedAt: DateTime.now(),
        );
        _results.add(result);
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({
          'score': result.score,
          'total': result.total,
          'percent': result.percent,
        }));
      } else if (path == '/results') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({
          'results': _results.map((r) => r.toJson()).toList(),
        }));
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write('Not found.');
      }
      await response.close();
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  int _grade(List<int?> answers) {
    final paper = _paper;
    if (paper == null) return 0;
    var score = 0;
    for (var i = 0; i < paper.questions.length && i < answers.length; i++) {
      if (answers[i] == paper.questions[i].correctIndex) score++;
    }
    return score;
  }
}
