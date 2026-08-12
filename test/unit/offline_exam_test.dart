import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/features/offline_exam/data/exam_ble.dart';
import 'package:nexus_edu/features/offline_exam/data/exam_client.dart';
import 'package:nexus_edu/features/offline_exam/data/exam_server.dart';
import 'package:nexus_edu/features/offline_exam/domain/offline_exam_models.dart';

OfflineExamPaper _paper() {
  return OfflineExamPaper(
    id: 'test-1',
    title: 'Physics Test',
    durationMinutes: 5,
    questions: const [
      OfflineExamQuestion(
        question: 'SI unit of force?',
        options: ['Joule', 'Newton', 'Watt'],
        correctIndex: 1,
      ),
      OfflineExamQuestion(
        question: '2 + 2?',
        options: ['3', '4', '5'],
        correctIndex: 1,
      ),
      OfflineExamQuestion(
        question: 'Red planet?',
        options: ['Mars', 'Venus', 'Jupiter'],
        correctIndex: 0,
      ),
    ],
  );
}

void main() {
  group('OfflineExamPaper', () {
    test('encode/decode round trips', () {
      final paper = _paper();
      final decoded = OfflineExamPaper.decode(paper.encode());
      expect(decoded!.id, paper.id);
      expect(decoded.title, paper.title);
      expect(decoded.questions.length, 3);
      expect(decoded.questions[1].correctIndex, 1);
      expect(decoded.questions[2].options, ['Mars', 'Venus', 'Jupiter']);
    });

    test('student JSON strips correct indexes', () {
      final student = _paper().toStudentJson();
      final questions = student['questions'] as List;
      expect((questions[0] as Map).containsKey('i'), isFalse);
      expect((questions[0] as Map)['q'], 'SI unit of force?');
    });

    test('decode rejects garbage', () {
      expect(OfflineExamPaper.decode('not-json'), isNull);
    });
  });

  group('ExamBleConstants chunking', () {
    test('chunk and decode round trip with padding', () {
      final payload = 'hello-world-${'x' * 450}';
      final chunks = ExamBleConstants.chunk(payload);
      expect(chunks.length, lessThanOrEqualTo(ExamBleConstants.chunkCount));
      expect(chunks.every((c) => c.length == ExamBleConstants.chunkSize), isTrue);
      final rebuilt = ExamBleConstants.decode(chunks.join());
      expect(rebuilt, payload);
    });

    test('short payload pads to one chunk', () {
      final chunks = ExamBleConstants.chunk('hi');
      expect(chunks.length, 1);
      expect(chunks.first.length, ExamBleConstants.chunkSize);
      expect(ExamBleConstants.decode(chunks.join()), 'hi');
    });

    test('payload larger than chunk budget is truncated gracefully', () {
      final chunks = ExamBleConstants.chunk('y' * 600);
      expect(chunks.length, ExamBleConstants.chunkCount);
    });
  });

  group('OfflineExamServer over HTTP', () {
    late OfflineExamServer server;
    late int port;
    const host = '127.0.0.1';

    setUp(() async {
      server = OfflineExamServer(port: 0);
      await server.start(_paper());
      port = server.boundPort;
    });

    tearDown(() => server.stop());

    test('health returns ok', () async {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://$host:$port/health'));
      final response = await request.close();
      final body = await response.transform(SystemEncoding().decoder).join();
      expect(response.statusCode, 200);
      expect(body, contains('"ok":true'));
      client.close(force: true);
    });

    test('student fetch gets paper without answers', () async {
      final client = OfflineExamClient();
      final paper = await client.fetchPaper(host, port);
      expect(paper, isNotNull);
      expect(paper!.title, 'Physics Test');
      expect(paper.questions.length, 3);
      expect(paper.questions.first.correctIndex, 0,
          reason: 'student copy should not leak the answer');
    });

    test('submit grades correctly and stores result', () async {
      final client = OfflineExamClient();
      final result = await client.submit(host, port, 'Riya', [1, 1, 0]);
      expect(result, isNotNull);
      expect(result!.$1, 3);
      expect(result.$2, 3);

      final serverResults = server.results;
      expect(serverResults.length, 1);
      expect(serverResults.first.studentName, 'Riya');
      expect(serverResults.first.percent, 100);
    });

    test('wrong answers score zero', () async {
      final client = OfflineExamClient();
      final result = await client.submit(host, port, 'Aman', [0, 0, 2]);
      expect(result!.$1, 0);
    });

    test('unreachable host returns null, no crash', () async {
      final client = OfflineExamClient();
      final paper = await client.fetchPaper('127.0.0.1', 1);
      expect(paper, isNull);
      final result = await client.submit('127.0.0.1', 1, 'X', [0]);
      expect(result, isNull);
    });

    test('not-found path returns 404', () async {
      final client = HttpClient();
      final request =
          await client.getUrl(Uri.parse('http://$host:$port/nope'));
      final response = await request.close();
      expect(response.statusCode, 404);
      client.close(force: true);
    });
  });
}
