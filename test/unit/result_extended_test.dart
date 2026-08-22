import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/utils/result.dart';

void main() {
  group('Result extended', () {
    test('Success isSuccess true, isFailure false', () {
      const r = Success<int>(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.dataOrNull, 42);
    });

    test('Failure carries kind and message', () {
      const f = Failure<int>('oops', kind: FailureKind.network);
      expect(f.isFailure, isTrue);
      expect(f.kind, FailureKind.network);
      expect(f.message, 'oops');
      expect(f.messageOrEmpty, 'oops');
    });

    test('Failure default kind unknown', () {
      const f = Failure<String>('err');
      expect(f.kind, FailureKind.unknown);
    });

    test('exhaustive switch', () {
      Result<String> r = const Success('ok');
      final out = switch (r) {
        Success(:final data) => 's:$data',
        Failure(:final message) => 'f:$message',
      };
      expect(out, 's:ok');

      r = const Failure('bad', kind: FailureKind.auth);
      final out2 = switch (r) {
        Success(:final data) => 's:$data',
        Failure(:final message, :final kind) => 'f:$message:${kind.name}',
      };
      expect(out2, 'f:bad:auth');
    });
  });
}
