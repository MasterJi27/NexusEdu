import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/app/auth_state.dart';
import 'package:nexus_edu/core/repositories/ai_repository.dart';
import 'package:nexus_edu/core/repositories/attendance_repository.dart';
import 'package:nexus_edu/core/repositories/auth_repository.dart';
import 'package:nexus_edu/core/repositories/classroom_repository.dart';
import 'package:nexus_edu/core/repositories/notes_repository.dart';
import 'package:nexus_edu/core/repositories/profile_repository.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/connectivity_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

// Core network + repositories — injectable for tests via ProviderScope overrides.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(api: SecureApiService()),
);

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(client: ref.watch(apiClientProvider)),
);

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(client: ref.watch(apiClientProvider)),
);

final classroomRepositoryProvider = Provider<ClassroomRepository>(
  (ref) => ClassroomRepository(client: ref.watch(apiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(client: ref.watch(apiClientProvider)),
);

// Singletons wrapped for Riverpod — override in tests.
final appSettingsProvider = Provider<AppSettings>((ref) => AppSettings.instance);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService.instance,
);

final secureApiServiceProvider = Provider<SecureApiService>(
  (ref) => SecureApiService(),
);

final authStateProvider = Provider<AuthState>((ref) => AuthState.instance);

final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository());
