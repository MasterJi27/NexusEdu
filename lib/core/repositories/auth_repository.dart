import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthRepository {
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';
  static const String _isLoggedInKey = 'isLoggedIn';

  Future<Result<AppUser>> login(String email, String password) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const Failure('Enter email and password.');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_userEmailKey);
    final user = AppUser(
      id: prefs.getString(_userIdKey) ?? const Uuid().v4(),
      name: prefs.getString(_userNameKey) ?? 'Alex Learner',
      email: savedEmail ?? normalizedEmail,
      role: _roleFromString(prefs.getString(_userRoleKey)),
    );

    await _persistSession(user);
    return Success(user);
  }

  Future<Result<AppUser>> signup(
    String name,
    String email,
    String password, {
    UserRole role = UserRole.student,
  }) async {
    final normalizedEmail = email.trim();
    if (name.trim().isEmpty || normalizedEmail.isEmpty || password.length < 6) {
      return const Failure(
        'Enter name, valid email, and a password with at least 6 characters.',
      );
    }

    final user = AppUser(
      id: const Uuid().v4(),
      name: name.trim(),
      email: normalizedEmail,
      role: role,
    );
    await _persistSession(user);
    return Success(user);
  }

  Future<Result<AppUser>> signInWithGoogle() async {
    final user = AppUser(
      id: const Uuid().v4(),
      name: 'Alex Learner',
      email: 'alex@nexusedu.local',
      photoUrl: 'https://i.pravatar.cc/300',
    );
    await _persistSession(user);
    return Success(user);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
  }

  Future<void> _persistSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_userNameKey, user.name);
    await prefs.setString(_userEmailKey, user.email);
    await prefs.setString(_userRoleKey, user.role.name);
  }

  UserRole _roleFromString(String? role) {
    return UserRole.values.firstWhere(
      (item) => item.name == role,
      orElse: () => UserRole.student,
    );
  }
}
