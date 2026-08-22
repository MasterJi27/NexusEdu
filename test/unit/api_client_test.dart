import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

void main() {
  group('ApiClient', () {
    test('decodeResponse success map', () async {
      final client = ApiClient(client: MockClient((_) async => http.Response('{"ok":true}', 200)));
      final res = await client.send('GET', '/api/health');
      expect(res.statusCode, 200);
      final decoded = client.decodeResponse(res);
      expect(decoded['ok'], true);
    });

    test('decodeResponse 401 maps to error', () {
      final client = ApiClient();
      final res = http.Response('{"error":"bad"}', 401);
      final decoded = client.decodeResponse(res) as Map;
      expect(decoded['error'], 'bad');
    });

    test('decodeResponse empty 200 returns empty map', () {
      final client = ApiClient();
      final res = http.Response('', 200);
      final decoded = client.decodeResponse(res);
      expect(decoded, isA<Map>());
      expect((decoded as Map).isEmpty, true);
    });

    test('requestResult success wraps Success', () async {
      final mock = MockClient((_) async => http.Response(jsonEncode({'data': 1}), 200));
      final client = ApiClient(client: mock);
      final result = await client.requestResult('GET', '/api/notes');
      expect(result, isA<Success<dynamic>>());
      expect((result as Success).data['data'], 1);
    });

    test('requestResult 500 wraps Failure server', () async {
      final mock = MockClient((_) async => http.Response('{"error":"boom"}', 500));
      final client = ApiClient(client: mock);
      final result = await client.requestResult('GET', '/api/notes');
      expect(result, isA<Failure<dynamic>>());
      final f = result as Failure;
      expect(f.kind, FailureKind.server);
    });

    test('requestResult timeout maps to network', () async {
      final mock = MockClient((_) async => throw http.ClientException('timeout'));
      final client = ApiClient(client: mock);
      final result = await client.requestResult('GET', '/api/notes');
      expect(result, isA<Failure<dynamic>>());
      expect((result as Failure).kind, FailureKind.network);
    });
  });
}
