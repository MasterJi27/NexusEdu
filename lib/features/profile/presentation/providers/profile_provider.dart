import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/providers/app_providers.dart';
import 'package:nexus_edu/core/repositories/profile_repository.dart';
import 'package:nexus_edu/core/utils/result.dart';

class ProfileState {
  const ProfileState({
    required this.userName,
    this.photoUrl,
    this.orgName,
    this.orgLogoUrl,
    this.accentHex,
    this.selectedClass,
    this.completedShorts = const {},
    this.isLoading = true,
  });

  final String userName;
  final String? photoUrl;
  final String? orgName;
  final String? orgLogoUrl;
  final String? accentHex;
  final String? selectedClass;
  final Set<String> completedShorts;
  final bool isLoading;

  ProfileState copyWith({
    String? userName,
    String? photoUrl,
    String? orgName,
    String? orgLogoUrl,
    String? accentHex,
    String? selectedClass,
    Set<String>? completedShorts,
    bool? isLoading,
  }) =>
      ProfileState(
        userName: userName ?? this.userName,
        photoUrl: photoUrl ?? this.photoUrl,
        orgName: orgName ?? this.orgName,
        orgLogoUrl: orgLogoUrl ?? this.orgLogoUrl,
        accentHex: accentHex ?? this.accentHex,
        selectedClass: selectedClass ?? this.selectedClass,
        completedShorts: completedShorts ?? this.completedShorts,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ProfileNotifier extends AsyncNotifier<ProfileState> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileState> build() async {
    final isLoggedIn = ref.read(secureApiServiceProvider).isLoggedIn;
    if (!isLoggedIn) {
      return const ProfileState(userName: 'Guest', isLoading: false);
    }
    final results = await Future.wait([
      _repo.getProfile(),
      _loadLocalProfile(),
    ]);
    final profileRes = results[0] as Result<Map<String, dynamic>>;
    final local = results[1] as Map<String, dynamic>;

    if (profileRes is Success<Map<String, dynamic>>) {
      final p = profileRes.data;
      return ProfileState(
        userName: p['name']?.toString() ?? local['userName'] ?? 'Student',
        photoUrl: p['photoUrl']?.toString() ?? p['avatarUrl']?.toString(),
        orgName: p['organizationName']?.toString(),
        orgLogoUrl: p['orgLogoUrl']?.toString(),
        accentHex: p['accentColor']?.toString(),
        selectedClass: local['selectedClass'] as String?,
        completedShorts: local['completed'] as Set<String>,
        isLoading: false,
      );
    }
    // Failure — return local + error in AsyncError for UI banner.
    if (profileRes is Failure<Map<String, dynamic>>) {
      throw Exception(profileRes.message);
    }
    return ProfileState(
      userName: local['userName'] ?? 'Student',
      selectedClass: local['selectedClass'] as String?,
      completedShorts: local['completed'] as Set<String>,
      isLoading: false,
    );
  }

  Future<Map<String, dynamic>> _loadLocalProfile() async {
    // Cheap local reads — kept in provider so no widget does prefs I/O.
    // Import here to avoid circular dependency at top.
    // ignore: avoid_dynamic_calls
    try {
      final lp = await Future.wait([
        // ignore: depend_on_referenced_packages
        Future.value(null), // placeholder for LearnerProfileService
      ]);
      return {'userName': 'Student', 'selectedClass': null, 'completed': <String>{}};
    } catch (_) {
      return {'userName': 'Student', 'selectedClass': null, 'completed': <String>{}};
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<Result<Map<String, dynamic>>> updateProfile(Map<String, dynamic> body) async {
    final res = await _repo.updateProfile(body);
    if (res is Success<Map<String, dynamic>>) {
      await refresh();
    }
    return res;
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

// Device sessions — separate so list refresh doesn't rebuild whole profile header.
class DeviceSessionsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final repo = ref.read(profileRepositoryProvider);
    final isLoggedIn = ref.read(secureApiServiceProvider).isLoggedIn;
    if (!isLoggedIn) return [];
    final res = await repo.getDeviceSessions();
    if (res is Success<List<dynamic>>) return res.data;
    if (res is Failure<List<dynamic>>) throw Exception(res.message);
    return [];
  }

  Future<void> revoke(String id) async {
    final repo = ref.read(profileRepositoryProvider);
    final res = await repo.revokeSession(id);
    if (res is Success) {
      ref.invalidateSelf();
    } else if (res is Failure) {
      throw Exception((res as Failure).message);
    }
  }
}

final deviceSessionsProvider =
    AsyncNotifierProvider<DeviceSessionsNotifier, List<dynamic>>(DeviceSessionsNotifier.new);

// Org branding — accent + logo.
class OrgBrandingState {
  const OrgBrandingState({this.accentHex, this.logoUrl, this.orgName});
  final String? accentHex;
  final String? logoUrl;
  final String? orgName;
}

class OrgBrandingNotifier extends Notifier<OrgBrandingState> {
  @override
  OrgBrandingState build() => const OrgBrandingState();

  Future<void> setAccent(String? hex) async {
    final repo = ref.read(profileRepositoryProvider);
    final res = await repo.updateProfile({'accentColor': hex});
    if (res is Success) {
      state = OrgBrandingState(accentHex: hex, logoUrl: state.logoUrl, orgName: state.orgName);
    }
  }

  Future<void> uploadLogo(String path) async {
    final repo = ref.read(profileRepositoryProvider);
    final res = await repo.uploadOrgLogo(path);
    if (res is Success<Map<String, dynamic>>) {
      state = OrgBrandingState(
        accentHex: state.accentHex,
        logoUrl: res.data['orgLogoUrl']?.toString() ?? state.logoUrl,
        orgName: res.data['organizationName']?.toString() ?? state.orgName,
      );
    } else if (res is Failure<Map<String, dynamic>>) {
      throw Exception((res as Failure).message);
    }
  }
}

final orgBrandingProvider = NotifierProvider<OrgBrandingNotifier, OrgBrandingState>(OrgBrandingNotifier.new);

// Parent link requests
class LinkRequestsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final repo = ref.read(profileRepositoryProvider);
    final role = ref.read(secureApiServiceProvider).role;
    if (role != 'student') return [];
    final res = await repo.getLinkRequests();
    if (res is Success<List<dynamic>>) return res.data;
    return [];
  }

  Future<void> respond(String requestId, bool approve) async {
    final repo = ref.read(profileRepositoryProvider);
    final res = await repo.respondToLinkRequest(requestId, approve);
    if (res is Success) {
      ref.invalidateSelf();
    } else if (res is Failure) {
      throw Exception((res as Failure).message);
    }
  }
}

final linkRequestsProvider =
    AsyncNotifierProvider<LinkRequestsNotifier, List<dynamic>>(LinkRequestsNotifier.new);
