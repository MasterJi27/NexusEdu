import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Success holds data', () {
      const result = Success<String>('hello');
      expect(result.data, 'hello');
    });

    test('Failure holds message', () {
      final result = Failure<String>('error occurred');
      expect(result.message, 'error occurred');
    });

    test('pattern matching works', () {
      Result<int> result = const Success(42);
      final value = switch (result) {
        Success<int> s => s.data,
        Failure<int> f => throw Exception(f.message),
      };
      expect(value, 42);
    });
  });
}
