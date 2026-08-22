import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/security/nonce_service.dart';

void main() {
  group('NonceService', () {
    test('generate produces 32-char hex string', () {
      final nonce = NonceService.generate();
      expect(nonce.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(nonce), isTrue);
    });

    test('generate produces unique nonces', () {
      final a = NonceService.generate();
      final b = NonceService.generate();
      final c = NonceService.generate();
      expect(a, isNot(equals(b)));
      expect(b, isNot(equals(c)));
      expect(a, isNot(equals(c)));
    });

    test('heartbeatId has same format as generate', () {
      final id = NonceService.heartbeatId();
      expect(id.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });

    test('bodyHash is deterministic sha256', () {
      final h1 = NonceService.bodyHash('hello');
      final h2 = NonceService.bodyHash('hello');
      final h3 = NonceService.bodyHash('world');
      expect(h1, equals(h2));
      expect(h1, isNot(equals(h3)));
      expect(h1.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h1), isTrue);
    });

    test('sign is deterministic and changes with inputs', () {
      const nonce = 'abc123';
      const ts = '1700000000000';
      const bodyHash = 'deadbeef';
      final s1 = NonceService.sign(nonce, ts, bodyHash);
      final s2 = NonceService.sign(nonce, ts, bodyHash);
      final s3 = NonceService.sign('different', ts, bodyHash);
      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
      expect(s1.length, 64);
    });

    test('consume returns true first time, false on replay', () {
      final nonce = NonceService.generate();
      expect(NonceService.consume(nonce), isTrue);
      expect(NonceService.consume(nonce), isFalse);
    });

    test('consume treats different nonces independently', () {
      final n1 = NonceService.generate();
      final n2 = NonceService.generate();
      expect(NonceService.consume(n1), isTrue);
      expect(NonceService.consume(n2), isTrue);
      expect(NonceService.consume(n1), isFalse);
      expect(NonceService.consume(n2), isFalse);
    });

    test(
      'validateResponse succeeds for fresh nonce+timestamp and consumes',
      () {
        final nonce = NonceService.generate();
        final ts = NonceService.timestamp();
        final first = NonceService.validateResponse(
          requestNonce: nonce,
          responseNonce: nonce,
          responseTs: ts,
        );
        expect(first, isTrue);
        // second attempt with same nonce must fail (replay)
        final second = NonceService.validateResponse(
          requestNonce: nonce,
          responseNonce: nonce,
          responseTs: ts,
        );
        expect(second, isFalse);
      },
    );

    test('validateResponse fails when nonces mismatch', () {
      final a = NonceService.generate();
      final b = NonceService.generate();
      final ts = NonceService.timestamp();
      expect(
        NonceService.validateResponse(
          requestNonce: a,
          responseNonce: b,
          responseTs: ts,
        ),
        isFalse,
      );
    });

    test('validateResponse fails for stale timestamp (>5min)', () {
      final nonce = NonceService.generate();
      final stale = (DateTime.now().millisecondsSinceEpoch - 10 * 60 * 1000)
          .toString();
      expect(
        NonceService.validateResponse(
          requestNonce: nonce,
          responseNonce: nonce,
          responseTs: stale,
        ),
        isFalse,
      );
    });

    test('validateResponse fails for future timestamp (>5min ahead)', () {
      final nonce = NonceService.generate();
      final future = (DateTime.now().millisecondsSinceEpoch + 10 * 60 * 1000)
          .toString();
      expect(
        NonceService.validateResponse(
          requestNonce: nonce,
          responseNonce: nonce,
          responseTs: future,
        ),
        isFalse,
      );
    });

    test('validateResponse fails for non-numeric timestamp', () {
      final nonce = NonceService.generate();
      expect(
        NonceService.validateResponse(
          requestNonce: nonce,
          responseNonce: nonce,
          responseTs: 'not-a-number',
        ),
        isFalse,
      );
    });

    test('timestamp is recent and parseable', () {
      final tsStr = NonceService.timestamp();
      final ts = int.tryParse(tsStr);
      expect(ts, isNotNull);
      final now = DateTime.now().millisecondsSinceEpoch;
      expect((now - ts!).abs(), lessThan(2000));
    });
  });
}
