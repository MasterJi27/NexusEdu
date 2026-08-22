import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Thin wrapper — auth already returns Result, but isolates UI from
/// SecureApiService singleton + makes mocking trivial via provider.
class AuthRepository {
  AuthRepository({SecureApiService? api}) : _api = api ?? SecureApiService();
  final SecureApiService _api;

  Future<Result<AppUser>> signup(String name, String email, String password, {String? role}) =>
      _api.signup(name, email, password, role: role);

  Future<Result<AppUser>> login(String email, String password) => _api.login(email, password);

  Future<void> logout() => _api.logout();

  Future<Map<String, dynamic>> forgotPassword(String email) => _api.forgotPassword(email);

  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) =>
      _api.resetPassword(token, newPassword);

  Future<Result<Map<String, dynamic>>> revokeDevicePreLogin(String email, String sessionId) async {
    try {
      await _api.revokeDevicePreLogin(email, sessionId);
      return const Success({});
    } catch (e) {
      return Failure(e.toString(), error: e);
    }
  }

  bool get isLoggedIn => _api.isLoggedIn;
  String? get token => _api.token;
  String? get userId => _api.userId;
  String? get role => _api.role;
}
