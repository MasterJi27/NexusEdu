import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';

void main() {
  testWidgets('NexusCard renders child widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusCard(
            child: const Text('Hello'),
          ),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('NexusCard triggers onTap', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusCard(
            onTap: () => tapped = true,
            child: const Text('Tap me'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tap me'));
    expect(tapped, true);
  });
}
