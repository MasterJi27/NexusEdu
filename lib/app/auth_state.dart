import 'package:flutter/foundation.dart';
import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/services/sync_service.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the app-level auth/onboarding/privacy flow.
/// The router listens to this and redirects, so every screen is protected by
/// construction — no screen can be reached while logged out or mid-onboarding.
class AuthState extends ChangeNotifier {
  AuthState._();
  static final AuthState instance = AuthState._();

  static const _privacyKey = 'privacy_accepted';
  static const _roleKey = 'selected_role';

  bool _privacyAccepted = false;
  bool _onboardingDone = false;
  String? _selectedRole;
  AppUser? _user;

  bool get isLoggedIn => SecureApiService().isLoggedIn;
  bool get privacyAccepted => _privacyAccepted;
  bool get onboardingDone => _onboardingDone;

  /// Role picked on the pre-auth welcome flow ("Who's using Nexus Edu?").
  /// Drives [roleHome] for guests and after login/signup. Null means the
  /// default student experience.
  String? get selectedRole => _selectedRole;

  /// True when the account still needs the student profile onboarding
  /// (grade/board/subjects). Teacher and parent accounts skip it.
  bool get needsProfileOnboarding => _selectedRole != 'teacher' && _selectedRole != 'parent';

  /// Home route for the current role: teacher/parent/student dashboards.
  String get roleHome {
    final role = _selectedRole ?? _user?.role.name;
    switch (role) {
      case 'teacher':
        return '/teacher-dashboard';
      case 'parent':
        return '/parent-dashboard';
      default:
        return '/dashboard';
    }
  }

  /// The signed-in user, if any. Populated by [login]/[signup]; null for
  /// guests and after [logout].
  AppUser? get user => _user;

  /// Load persisted flags at startup (before the first route resolves).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _privacyAccepted = prefs.getBool(_privacyKey) ?? false;
    _selectedRole = prefs.getString(_roleKey);
    _onboardingDone = await LearnerProfileService.isOnboardingProfileDone();
    notifyListeners();
  }

  /// Persists the role chosen on the welcome flow. A null role resets to the
  /// default student experience.
  Future<void> setSelectedRole(String? role) async {
    _selectedRole = role;
    final prefs = await SharedPreferences.getInstance();
    if (role == null) {
      await prefs.remove(_roleKey);
    } else {
      await prefs.setString(_roleKey, role);
    }
    notifyListeners();
  }

  /// Route to send a *newly created* account to.
  ///
  /// Signup always creates a 'student' account server-side, so a teacher or
  /// parent choice made on the signup form is pushed through the profile
  /// endpoint here (which reissues the JWT with the right role claim). This is
  /// the only place a client-chosen role is allowed to change an account.
  Future<String> resolveHomeAfterSignup() async {
    final role = _selectedRole;
    if (role == 'teacher' || role == 'parent') {
      final api = SecureApiService();
      if (api.isLoggedIn && api.role != role) {
        try {
          await api.updateProfile(role: role);
        } catch (_) {
          // Best-effort: the local role still routes to the right dashboard.
        }
      }
    }
    return roleHome;
  }

  /// Route to send an *existing* account to after signing in.
  ///
  /// The stored account role is the only truth here, so it is adopted into
  /// local state rather than pushed. Deliberately never calls updateProfile:
  /// syncing a locally-picked role on this path let anyone promote their own
  /// account to teacher or parent — gaining course creation, attendance
  /// control over other students, and access to teacher notes — just by
  /// choosing it on the sign-in form.
  Future<String> resolveHomeAfterLogin() async {
    final serverRole = _user?.role.name ?? SecureApiService().role;
    if (serverRole != null && serverRole != _selectedRole) {
      await setSelectedRole(serverRole);
    }
    return roleHome;
  }

  Future<void> _setPrivacyAccepted(bool value) async {
    _privacyAccepted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyKey, value);
    notifyListeners();
  }

  /// Called right after a successful login/signup.
  Future<void> markLoggedIn() => _setPrivacyAccepted(true);

  /// Signs in against the backend. On success the session is stored and the
  /// router guard is updated; on failure a typed [Failure] is returned.
  Future<Result<AppUser>> login(String email, String password) async {
    final result = await SecureApiService().login(email, password);
    if (result is Success<AppUser>) {
      _user = result.data;
      await markLoggedIn();
      SyncService.syncAfterLogin();
    }
    return result;
  }

  /// Creates an account. Same contract as [login].
  Future<Result<AppUser>> signup(
    String name,
    String email,
    String password,
  ) async {
    final result = await SecureApiService().signup(name, email, password);
    if (result is Success<AppUser>) {
      _user = result.data;
      await markLoggedIn();
      SyncService.syncAfterLogin();
    }
    return result;
  }

  /// Called when the user accepts the privacy policy.
  Future<void> markPrivacyAccepted() => _setPrivacyAccepted(true);

  /// "Continue as Guest" flow — guest users skip privacy too.
  Future<void> markGuest() => _setPrivacyAccepted(true);

  /// Called when onboarding profile setup completes.
  Future<void> markOnboardingDone() async {
    await LearnerProfileService.markOnboardingProfileDone();
    _onboardingDone = true;
    notifyListeners();
  }

  /// Full logout: revokes the session server-side and resets local state.
  Future<void> logout() async {
    await SecureApiService().logout();
    _user = null;
    _selectedRole = null;
    await _setPrivacyAccepted(false);
    _onboardingDone = false;
    notifyListeners();
  }

  /// Re-evaluate state after anything else changed prefs (e.g. profile edits).
  Future<void> refresh() async {
    _onboardingDone = await LearnerProfileService.isOnboardingProfileDone();
    final prefs = await SharedPreferences.getInstance();
    _privacyAccepted = prefs.getBool(_privacyKey) ?? false;
    notifyListeners();
  }
}
