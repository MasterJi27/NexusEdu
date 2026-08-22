import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/features/notes/presentation/providers/notes_provider.dart';

void main() {
  group('Notes QR codec', () {
    test('encode/decode round-trip', () {
      final note = Note(title: 'Hello', content: 'World', date: 'Today', subject: 'Physics', colorIndex: 2);
      final payload = NotesNotifier.encodeNoteToQrPayload(note);
      expect(payload.startsWith('nexusedu://note/'), isTrue);
      final decoded = NotesNotifier.decodeNoteFromQrPayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!.title, 'Hello');
      expect(decoded.content, 'World');
      expect(decoded.subject, 'Physics');
    });

    test('invalid payload returns null', () {
      expect(NotesNotifier.decodeNoteFromQrPayload('invalid'), isNull);
      expect(NotesNotifier.decodeNoteFromQrPayload('https://example.com'), isNull);
      expect(NotesNotifier.decodeNoteFromQrPayload('nexusedu://note/!!!'), isNull);
    });

    test('Note.fromMap defaults', () {
      final n = Note.fromMap({'title': 'T'});
      expect(n.content, '');
      expect(n.subject, 'General');
      expect(n.date, '');
    });
  });
}
