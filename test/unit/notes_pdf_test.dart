import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/features/notes/presentation/screens/notes_screen.dart';

void main() {
  test('stripMarkdownForPdf removes markup, keeps bullets', () {
    const md = '## Photosynthesis\n\n**Key points:**\n- Light energy\n- Chlorophyll `green`\n\nE = mc^2';
    final out = stripMarkdownForPdf(md);
    expect(out.contains('Photosynthesis'), isTrue);
    expect(out.contains('#'), isFalse);
    expect(out.contains('**'), isFalse);
    expect(out.contains('• Light energy'), isTrue);
    expect(out.contains('E = mc^2'), isTrue);
  });

  test('buildNotePdf produces a valid PDF document', () async {
    final bytes = await buildNotePdf(
      title: 'Physics',
      subject: 'Physics',
      date: 'Today',
      content: '## Force\n\nF = m × a',
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
  });
}
