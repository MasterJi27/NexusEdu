import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';

void main() {
  testWidgets('NexusButton shows label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusButton(label: 'Submit'),
        ),
      ),
    );

    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('NexusButton triggers onPressed', (tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusButton(
            label: 'Click',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Click'));
    expect(pressed, true);
  });

  testWidgets('NexusButton shows loading indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NexusButton(label: 'Submit', isLoading: true),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
  });
}
