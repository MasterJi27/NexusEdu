import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/features/notes/presentation/screens/notes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest sees demo notes when cache is empty', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    await AppSettings.instance.load();
    await SecureApiService().init();
    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('AI & Machine Learning'), findsOneWidget);
    expect(find.text('Physics Formulas'), findsOneWidget);
  });

  testWidgets('logged-in student never sees demo notes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({'auth_token': 't'});
    await AppSettings.instance.load();
    await SecureApiService().init();
    expect(SecureApiService().isLoggedIn, isTrue);
    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('AI & Machine Learning'), findsNothing);
    expect(find.text('Physics Formulas'), findsNothing);
    expect(find.text('No notes yet'), findsOneWidget);
  });
}
