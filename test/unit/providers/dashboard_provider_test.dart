import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_edu/core/providers/app_providers.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/subject_progress_service.dart';
import 'package:nexus_edu/features/dashboard/presentation/providers/dashboard_provider.dart';

class MockAppSettings extends Mock implements AppSettings {}

class MockSecureApiService extends Mock implements SecureApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardState', () {
    test('overallProgress is 0 when no subjects', () {
      const state = DashboardState(
        selectedClass: null,
        isLoggedIn: false,
        xp: 0,
        level: 1,
        levelProgress: 0,
        streak: 0,
        streakSaverUsed: false,
        subjects: [],
        quizDoneToday: false,
      );
      expect(state.overallProgress, 0);
    });

    test('overallProgress averages completed/total across subjects', () {
      final subjects = [
        SubjectProgress(
          name: 'Physics',
          icon: '📘',
          totalChapters: 10,
          completedChapters: 5,
        ),
        SubjectProgress(
          name: 'Maths',
          icon: '📕',
          totalChapters: 10,
          completedChapters: 10,
        ),
      ];
      final state = DashboardState(
        selectedClass: 'Class 10',
        isLoggedIn: true,
        xp: 120,
        level: 2,
        levelProgress: 0.4,
        streak: 3,
        streakSaverUsed: false,
        subjects: subjects,
        quizDoneToday: false,
      );
      // (5+10)/(10+10) = 0.75
      expect(state.overallProgress, closeTo(0.75, 0.001));
    });

    test('overallProgress is 0 when total is 0', () {
      final subjects = [
        SubjectProgress(
          name: 'Empty',
          icon: '📘',
          totalChapters: 0,
          completedChapters: 0,
        ),
      ];
      final state = DashboardState(
        selectedClass: null,
        isLoggedIn: false,
        xp: 0,
        level: 1,
        levelProgress: 0,
        streak: 0,
        streakSaverUsed: false,
        subjects: subjects,
        quizDoneToday: false,
      );
      expect(state.overallProgress, 0);
    });

    test('holds weakestSubject and daysLeft', () {
      final weak = SubjectProgress(
        name: 'Biology',
        icon: '📙',
        totalChapters: 10,
        completedChapters: 2,
      );
      final strong = SubjectProgress(
        name: 'Physics',
        icon: '📘',
        totalChapters: 10,
        completedChapters: 8,
      );
      final state = DashboardState(
        selectedClass: 'Class 12',
        isLoggedIn: true,
        xp: 200,
        level: 3,
        levelProgress: 0.2,
        streak: 7,
        streakSaverUsed: true,
        subjects: [weak, strong],
        quizDoneToday: true,
        daysLeft: 42,
        weakestSubject: weak,
      );
      expect(state.weakestSubject?.name, 'Biology');
      expect(state.daysLeft, 42);
      expect(state.quizDoneToday, isTrue);
      expect(state.streakSaverUsed, isTrue);
    });
  });

  group('DashboardNotifier with ProviderContainer', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('build loads with mocked AppSettings and SecureApiService', () async {
      final mockSettings = MockAppSettings();
      when(() => mockSettings.examDate).thenReturn(null);
      when(() => mockSettings.streak).thenReturn(3);
      when(() => mockSettings.streakSaverUsed).thenReturn(false);

      final mockApi = MockSecureApiService();
      when(() => mockApi.isLoggedIn).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(mockSettings),
          secureApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(dashboardProvider.future);
      expect(state.streak, 3);
      expect(state.isLoggedIn, isFalse);
      expect(state.xp, isA<int>());
      expect(state.level, greaterThanOrEqualTo(1));
      expect(state.subjects, isNotEmpty);
      expect(state.overallProgress, greaterThanOrEqualTo(0));
    });

    test('build respects examDate for daysLeft', () async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final mockSettings = MockAppSettings();
      when(() => mockSettings.examDate).thenReturn(futureDate);
      when(() => mockSettings.streak).thenReturn(1);
      when(() => mockSettings.streakSaverUsed).thenReturn(false);

      final mockApi = MockSecureApiService();
      when(() => mockApi.isLoggedIn).thenReturn(true);

      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(mockSettings),
          secureApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(dashboardProvider.future);
      expect(state.daysLeft, isNotNull);
      expect(state.daysLeft, greaterThanOrEqualTo(28));
      expect(state.daysLeft, lessThanOrEqualTo(30));
    });

    test('setSelectedClass updates selectedClass', () async {
      final mockSettings = MockAppSettings();
      when(() => mockSettings.examDate).thenReturn(null);
      when(() => mockSettings.streak).thenReturn(0);
      when(() => mockSettings.streakSaverUsed).thenReturn(false);

      final mockApi = MockSecureApiService();
      when(() => mockApi.isLoggedIn).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(mockSettings),
          secureApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dashboardProvider.future);
      final notifier = container.read(dashboardProvider.notifier);
      await notifier.setSelectedClass('Class 11');
      final after = container.read(dashboardProvider).value!;
      expect(after.selectedClass, 'Class 11');
    });

    test('refresh reloads without throwing', () async {
      final mockSettings = MockAppSettings();
      when(() => mockSettings.examDate).thenReturn(null);
      when(() => mockSettings.streak).thenReturn(2);
      when(() => mockSettings.streakSaverUsed).thenReturn(false);

      final mockApi = MockSecureApiService();
      when(() => mockApi.isLoggedIn).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          appSettingsProvider.overrideWithValue(mockSettings),
          secureApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dashboardProvider.future);
      await container.read(dashboardProvider.notifier).refresh();
      expect(container.read(dashboardProvider).hasValue, isTrue);
    });
  });
}
