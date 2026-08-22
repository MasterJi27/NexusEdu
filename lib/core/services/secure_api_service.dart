import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:nexus_edu/core/models/app_user.dart';
import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Talks to the real NexusEdu backend (Express + Prisma, deployed on Azure).
class SecureApiService {
  static final SecureApiService _instance = SecureApiService._();
  factory SecureApiService() => _instance;
  SecureApiService._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nexus-edu-backend.azurewebsites.net',
  );

  static const _storage = FlutterSecureStorage();
  static const _uuid = Uuid();
  static const _authTokenKey = 'auth_token';
  static const _authUserIdKey = 'auth_user_id';
  static const _authUserNameKey = 'auth_user_name';
  static const _authRoleKey = 'auth_role';
  static const _deviceIdKey = 'auth_device_id';

  String? _token;
  String? _userId;
  String? _userName;
  String? _role;

  String? _organizationName;
  String? _orgLogoUrl;
  String? _accentColorHex;

  bool get isLoggedIn => _token != null;
  String get userName => _userName ?? 'Guest';
  String? get token => _token;
  String? get userId => _userId;
  String? get role => _role;
  bool get isTeacher => _role == 'teacher';
  String? get organizationName => _organizationName;
  String? get orgLogoUrl => _orgLogoUrl;
  String? get accentColorHex => _accentColorHex;

  void _syncOrgBranding(Map<String, dynamic> profile) {
    final name = profile['organizationName'] as String?;
    final logo = profile['orgLogoUrl'] as String?;
    final accent =
        (profile['accentColor'] ?? profile['accent_color']) as String?;
    _organizationName = name;
    _orgLogoUrl = logo;
    _accentColorHex = accent;
  }

  Future<String?> _readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureApiService: Secure storage read failed for $key: $e');
      return null;
    }
  }

  // Deliberately no SharedPreferences fallback: auth data is a 30-day session
  // credential and must never be persisted in plaintext prefs (readable via
  // adb on a compromised device, included in Android auto-backup). On secure
  // storage failure the session stays in memory only and is lost on restart —
  // the user logs in again, which is the correct fail-closed behavior.
  Future<void> _writeSecure(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint(
        'SecureApiService: Secure storage write failed for $key (session kept in memory only): $e',
      );
      // TODO: propagate to UI via Result so caller can show Snackbar once via
      // ErrorReportingService if needed; currently swallowed to keep session in
      // memory-only (fail-closed) and avoid crashing login flow.
    }
  }

  Future<void> _deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureApiService: Secure storage delete failed for $key: $e');
    }
  }

  /// Older builds wrote auth values to SharedPreferences under `fallback_*`
  /// when secure storage failed. Purge any leftovers so a plaintext token
  /// never survives in prefs after upgrade.
  static const _authKeys = [
    _authTokenKey,
    _authUserIdKey,
    _authUserNameKey,
    _authRoleKey,
  ];

  Future<void> _purgeLegacyPrefsFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _authKeys) {
        await prefs.remove('fallback_$key');
      }
    } catch (_) {
      // Best-effort cleanup; nothing depends on it.
    }
  }

  Future<void> init() async {
    await _purgeLegacyPrefsFallback();
    _token = await _readSecure(_authTokenKey);
    _userId = await _readSecure(_authUserIdKey);
    _userName = await _readSecure(_authUserNameKey);
    _role = await _readSecure(_authRoleKey);
  }

  Future<void> _saveSession(
    String token,
    String userId,
    String name, [
    String? role,
  ]) async {
    _token = token;
    _userId = userId;
    _userName = name;
    _role = role;
    await _writeSecure(_authTokenKey, token);
    await _writeSecure(_authUserIdKey, userId);
    await _writeSecure(_authUserNameKey, name);
    if (role != null) {
      await _writeSecure(_authRoleKey, role);
    } else {
      await _deleteSecure(_authRoleKey);
    }
  }

  Future<void> _clearSession() async {
    _token = null;
    _userId = null;
    _userName = null;
    _role = null;
    _organizationName = null;
    _orgLogoUrl = null;
    _accentColorHex = null;
    await _deleteSecure(_authTokenKey);
    await _deleteSecure(_authUserIdKey);
    await _deleteSecure(_authUserNameKey);
    await _deleteSecure(_authRoleKey);
  }

  Future<String> _getDeviceId() async {
    final existing = await _readSecure(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await _writeSecure(_deviceIdKey, created);
    return created;
  }

  String get _deviceName => 'NexusEdu ${defaultTargetPlatform.name}';

  Future<Map<String, String>> _buildHeaders() async {
    final deviceId = await _getDeviceId();
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId,
      'X-Device-Name': _deviceName,
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  /// Dual HTTP stack deprecation: this service keeps its own `_send`/`_request`
  /// for legacy callers, but new code should use the single stack in
  /// [ApiClient.requestResult] (headers, timeouts, device-id, Result wrapping).
  /// These helpers are kept for backward compat and will be removed once all
  /// call sites migrate to repositories that inject [ApiClient].
  @Deprecated(
    'Use ApiClient.requestResult instead — dual stack, prefer single ApiClient',
  )
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _send(method, Uri.parse('$baseUrl$path'), body);
      final decoded = await _decodeResponse(response);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'error': 'Unexpected server response. Please try again.'};
    } catch (e) {
      return {'error': 'Connection failed. Please check your internet.'};
    }
  }

  /// Like [_request], but for endpoints that may return a JSON array (or an
  /// empty body on success) instead of an object.
  /// @deprecated Prefer [ApiClient.requestResult] — see [_request] note.
  @Deprecated(
    'Use ApiClient.requestResult instead — dual stack, prefer single ApiClient',
  )
  Future<dynamic> _requestRaw(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _send(method, Uri.parse('$baseUrl$path'), body);
      return _decodeResponse(response);
    } catch (e) {
      return {'error': 'Connection failed. Please check your internet.'};
    }
  }

  /// Public entry point for callers that need the raw [http.Response] because
  /// they parse a shape [_request]/[_requestRaw] don't return (e.g. an
  /// OpenAI-style `choices[0].message.content`) — but still want this
  /// class's single source of truth for auth headers, device id, and
  /// timeouts instead of reimplementing `'Authorization': 'Bearer $_token'`
  /// and a fresh `http.post(...)` call at every AI service in the app.
  /// Throws on a network failure; callers should catch and handle it (unlike
  /// [_request], which swallows failures into a soft `{'error': ...}` map).
  Future<http.Response> sendAuthenticated(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(method, Uri.parse('$baseUrl$path'), body);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
  ) async {
    final headers = await _buildHeaders();
    final encodedBody = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
      case 'POST':
        return http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 60));
      case 'PUT':
        return http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 30));
      default:
        return http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
    }
  }

  Future<Map<String, dynamic>> _withDevicePayload(
    Map<String, dynamic> body,
  ) async {
    return {
      ...body,
      'deviceId': await _getDeviceId(),
      'deviceName': _deviceName,
    };
  }

  Future<dynamic> _decodeResponse(http.Response response) async {
    if (response.statusCode == 401) {
      await _clearSession();
      return {'error': 'Session expired. Please login again.'};
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return response.statusCode >= 400
          ? {
              'error':
                  'Server error (${response.statusCode}). Please try again.',
            }
          : {};
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return {
        'error': response.statusCode >= 400
            ? 'Server error (${response.statusCode}). Please try again.'
            : 'Unexpected server response. Please try again.',
      };
    }

    if (response.statusCode >= 400) {
      if (decoded is Map) {
        final message = decoded['error'] ?? decoded['message'];
        if (message != null) {
          return {'error': message.toString()};
        }
      }
      return {
        'error': 'Server error (${response.statusCode}). Please try again.',
      };
    }

    return decoded;
  }

  // Auth
  Future<Result<AppUser>> signup(
    String name,
    String email,
    String password,
  ) async {
    final result = await _request(
      'POST',
      '/api/auth/signup',
      body: await _withDevicePayload({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    return _saveSessionFromResult(result, name);
  }

  Future<Result<AppUser>> login(String email, String password) async {
    final result = await _request(
      'POST',
      '/api/auth/login',
      body: await _withDevicePayload({'email': email, 'password': password}),
    );
    return _saveSessionFromResult(result, email);
  }

  /// Persists the session when the backend returns `token` + `user`, and maps
  /// the outcome to a typed [Result]. All auth errors flow through here, so
  /// screens only ever see [Success] or [Failure] — never raw maps.
  Future<Result<AppUser>> _saveSessionFromResult(
    Map<String, dynamic> result,
    String fallbackName, {
    String? fallbackRole,
  }) async {
    final user = result['user'];
    if (result['token'] is String && user is Map) {
      try {
        final id = user['id']?.toString() ?? '';
        final appUser = AppUser.fromMap(Map<String, dynamic>.from(user), id);
        await _saveSession(
          result['token'] as String,
          id,
          user['name']?.toString() ?? fallbackName,
          user['role']?.toString() ?? fallbackRole,
        );
        return Success(appUser);
      } catch (e) {
        return Failure(
          'Unexpected server response. Please try again.',
          error: e,
        );
      }
    }
    final message = result['error']?.toString();
    if (message != null && message.isNotEmpty) {
      return Failure(message);
    }
    return Failure('Login failed. Please try again.');
  }

  Future<void> logout() async {
    if (_token != null) {
      await _requestRaw('POST', '/api/auth/logout');
    }
    await _clearSession();
  }

  /// Requests a password-reset token for [email]. In dev mode the backend
  /// returns a `devToken` so the app can complete the flow end-to-end.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _request(
      'POST',
      '/api/auth/forgot-password',
      body: {'email': email},
    );
  }

  /// Completes the reset with the emailed token and a new password.
  Future<Map<String, dynamic>> resetPassword(
    String token,
    String newPassword,
  ) async {
    return _request(
      'POST',
      '/api/auth/reset-password',
      body: {'token': token, 'newPassword': newPassword},
    );
  }

  /// AI usage + token stats from the backend ("kya aa raha hai, kya nahi").
  Future<Map<String, dynamic>> getAiUsage() async {
    return _request('GET', '/api/ai/usage');
  }

  Future<Result<Map<String, dynamic>>> getAiUsageResult() async {
    try {
      final result = await getAiUsage();
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to load AI usage.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> forgotPasswordResult(
    String email,
  ) async {
    try {
      final result = await forgotPassword(email);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to send reset link.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> resetPasswordResult(
    String token,
    String newPassword,
  ) async {
    try {
      final result = await resetPassword(token, newPassword);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to reset password.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> revokeDeviceSessionResult(
    String sessionId,
  ) async {
    try {
      final result = await revokeDeviceSession(sessionId);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to revoke device.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> linkChildResult(
    String studentEmail,
  ) async {
    try {
      final result = await linkChild(studentEmail);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to link child.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> createSectionResult({
    required String label,
    required String gradeLevel,
    String? subject,
  }) async {
    try {
      final result = await createSection(
        label: label,
        gradeLevel: gradeLevel,
        subject: subject,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to create section.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> markAttendanceResult(
    String sessionId,
    String code, {
    double? lat,
    double? lng,
    bool? isMocked,
  }) async {
    try {
      final result = await markAttendance(
        sessionId,
        code,
        lat: lat,
        lng: lng,
        isMocked: isMocked,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to mark attendance.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<List<dynamic>>> getMyOpenAttendanceSessionsResult() async {
    try {
      final sessions = await getMyOpenAttendanceSessions();
      return Success(sessions);
    } catch (e) {
      return Failure(
        'Failed to load attendance sessions.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> postSyllabusResult({
    required String sectionId,
    required String title,
    required String syllabus,
  }) async {
    try {
      final result = await postSyllabus(
        sectionId: sectionId,
        title: title,
        syllabus: syllabus,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to post syllabus.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> createClassTaskResult({
    required String sectionId,
    required String title,
    String? description,
    DateTime? dueDate,
    int points = 0,
  }) async {
    try {
      final result = await createClassTask(
        sectionId: sectionId,
        title: title,
        description: description,
        dueDate: dueDate,
        points: points,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to create task.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> addStudentToSectionResult(
    String sectionId,
    String studentEmail,
  ) async {
    try {
      final result = await addStudentToSection(sectionId, studentEmail);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to add student.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<List<dynamic>> getDeviceSessions() async {
    final result = await _requestRaw('GET', '/api/auth/sessions');
    return result is List ? result : const [];
  }

  Future<Map<String, dynamic>> revokeDeviceSession(String sessionId) async {
    final result = await _requestRaw('DELETE', '/api/auth/sessions/$sessionId');
    return result is Map<String, dynamic> ? result : {};
  }

  // User profile
  Future<Map<String, dynamic>> getProfile() async {
    final result = await _request('GET', '/api/users/profile');
    if (result['error'] == null) _syncOrgBranding(result);
    return result;
  }

  /// Result-typed wrapper for callers migrating off raw Map error handling.
  Future<Result<Map<String, dynamic>>> getProfileResult() async {
    try {
      final result = await _request('GET', '/api/users/profile');
      if (result['error'] != null) return Failure(result['error'].toString());
      _syncOrgBranding(result);
      return Success(result);
    } catch (e) {
      return Failure(
        'Connection failed. Please check your internet.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<List<dynamic>>> getTeacherNotesResult({
    String? gradeLevel,
    String? subject,
  }) async {
    try {
      final notes = await getTeacherNotes(
        gradeLevel: gradeLevel,
        subject: subject,
      );
      return Success(notes);
    } catch (e) {
      return Failure(
        'Failed to load class notes.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<List<dynamic>>> getNotesResult() async {
    try {
      final notes = await getNotes();
      return Success(notes);
    } catch (e) {
      return Failure(
        'Failed to load notes.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<List<dynamic>>> getSectionsResult() async {
    try {
      final sections = await getSections();
      return Success(sections);
    } catch (e) {
      return Failure(
        'Failed to load sections.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<List<dynamic>>> getLeaderboardResult() async {
    try {
      final entries = await getLeaderboard();
      return Success(entries);
    } catch (e) {
      return Failure(
        'Failed to load leaderboard.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> getTeacherHomeResult() async {
    try {
      final result = await getTeacherHome();
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to load teacher home.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> getLiveClassTokenResult(
    String liveSessionId,
  ) async {
    try {
      final result = await getLiveClassToken(liveSessionId);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to load live session.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> getInstituteLiveClassesResult() async {
    try {
      final result = await getInstituteLiveClasses();
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to load live classes.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> joinSectionByInviteResult(
    String inviteCode,
  ) async {
    try {
      final result = await joinSectionByInvite(inviteCode);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to join classroom.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> createTeacherNoteResult({
    required String title,
    required String content,
    required String gradeLevel,
    required String subject,
    String? topic,
  }) async {
    try {
      final result = await createTeacherNote(
        title: title,
        content: content,
        gradeLevel: gradeLevel,
        subject: subject,
        topic: topic,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to create note.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> deleteTeacherNoteResult(
    String id,
  ) async {
    try {
      final result = await deleteTeacherNote(id);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to delete note.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> updateProfileResult({
    String? name,
    String? currentPassword,
    String? newPassword,
    String? gradeLevel,
    String? schoolBoard,
    List<String>? weakSubjects,
    List<String>? strongSubjects,
    String? role,
    String? organizationName,
    String? accentColor,
    String? orgLogoUrl,
  }) async {
    try {
      final result = await updateProfile(
        name: name,
        currentPassword: currentPassword,
        newPassword: newPassword,
        gradeLevel: gradeLevel,
        schoolBoard: schoolBoard,
        weakSubjects: weakSubjects,
        strongSubjects: strongSubjects,
        role: role,
        organizationName: organizationName,
        accentColor: accentColor,
        orgLogoUrl: orgLogoUrl,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to update profile.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> getAdminUsersResult({
    String query = '',
  }) async {
    try {
      final result = await getAdminUsers(query: query);
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to load users.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> createImAccountResult({
    required String name,
    required String email,
    required String password,
    required List<String> permissions,
  }) async {
    try {
      final result = await createImAccount(
        name: name,
        email: email,
        password: password,
        permissions: permissions,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to create account.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Result<Map<String, dynamic>>> assignUserRoleResult(
    String userId, {
    required String role,
    List<String> permissions = const [],
  }) async {
    try {
      final result = await assignUserRole(
        userId,
        role: role,
        permissions: permissions,
      );
      if (result['error'] != null) return Failure(result['error'].toString());
      return Success(result);
    } catch (e) {
      return Failure(
        'Failed to assign role.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? currentPassword,
    String? newPassword,
    String? gradeLevel,
    String? schoolBoard,
    List<String>? weakSubjects,
    List<String>? strongSubjects,
    String? role,
    String? organizationName,
    String? accentColor,
    String? orgLogoUrl,
  }) async {
    // Client-side validation for 1M: accentColor must be hex, role gate for org fields
    if (accentColor != null && accentColor.isNotEmpty) {
      final ok = RegExp(
        r'^#([0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?)$',
      ).hasMatch(accentColor);
      if (!ok) return {'error': 'Invalid accent color. Use #RRGGBB format.'};
    }
    if ((organizationName != null || accentColor != null) &&
        (_role == 'student' || _role == 'parent')) {
      return {'error': 'Only teachers/admins can edit organization'};
    }
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (currentPassword != null) body['currentPassword'] = currentPassword;
    if (newPassword != null) body['newPassword'] = newPassword;
    if (gradeLevel != null) body['gradeLevel'] = gradeLevel;
    if (schoolBoard != null) body['schoolBoard'] = schoolBoard;
    if (weakSubjects != null) body['weakSubjects'] = weakSubjects;
    if (strongSubjects != null) body['strongSubjects'] = strongSubjects;
    if (role != null) body['role'] = role;
    if (organizationName != null) body['organizationName'] = organizationName;
    if (accentColor != null) body['accentColor'] = accentColor;
    if (orgLogoUrl != null) body['orgLogoUrl'] = orgLogoUrl;

    final result = await _request('PUT', '/api/users/profile', body: body);
    if (result['error'] == null) _syncOrgBranding(result);
    if (result['role'] != null) {
      _role = result['role'];
      await _writeSecure(_authRoleKey, _role!);
    }
    // A role change makes the backend reissue the JWT (the old token's role
    // claim would otherwise keep failing role-gated endpoints).
    if (result['token'] != null) {
      _token = result['token'];
      await _writeSecure(_authTokenKey, _token!);
    }
    return result;
  }

  // Teacher notes
  Future<List<dynamic>> getTeacherNotes({
    String? gradeLevel,
    String? subject,
  }) async {
    final query = <String>[];
    if (gradeLevel != null) {
      query.add('gradeLevel=${Uri.encodeQueryComponent(gradeLevel)}');
    }
    if (subject != null) {
      query.add('subject=${Uri.encodeQueryComponent(subject)}');
    }
    final qs = query.isEmpty ? '' : '?${query.join('&')}';
    final result = await _requestRaw('GET', '/api/teacher-notes$qs');
    return result is List ? result : const [];
  }

  Future<Map<String, dynamic>> createTeacherNote({
    required String title,
    required String content,
    required String gradeLevel,
    required String subject,
    String? topic,
  }) async {
    final body = {
      'title': title,
      'content': content,
      'gradeLevel': gradeLevel,
      'subject': subject,
    };
    if (topic != null) {
      body['topic'] = topic;
    }

    return _request('POST', '/api/teacher-notes', body: body);
  }

  Future<Map<String, dynamic>> deleteTeacherNote(String id) async {
    final result = await _requestRaw('DELETE', '/api/teacher-notes/$id');
    return result is Map<String, dynamic> ? result : {};
  }

  // ---- Student's own notes (synced to /api/notes) ----

  Future<List<dynamic>> getNotes() async {
    final result = await _requestRaw('GET', '/api/notes');
    return result is List ? result : const [];
  }

  Future<Map<String, dynamic>> createNote({
    required String title,
    required String content,
    double? latitude,
    double? longitude,
  }) async {
    return _request(
      'POST',
      '/api/notes',
      body: {
        'title': title,
        'content': content,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  Future<Map<String, dynamic>> updateNote({
    required String id,
    required String title,
    required String content,
    double? latitude,
    double? longitude,
  }) async {
    return _request(
      'PUT',
      '/api/notes/$id',
      body: {
        'title': title,
        'content': content,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  Future<Map<String, dynamic>> deleteNote(String id) async {
    final result = await _requestRaw('DELETE', '/api/notes/$id');
    return result is Map<String, dynamic> ? result : {};
  }

  /// Pushes the app's local gamification numbers to the server so the
  /// leaderboard shows real effort. Fire-and-forget: failures are swallowed.
  Future<void> pushProgress({int? xp, int? streak}) async {
    try {
      final body = <String, dynamic>{
        if (xp != null) 'xp': xp,
        if (streak != null) 'streak': streak,
      };
      if (body.isEmpty) return;
      await _requestRaw('PUT', '/api/users/progress', body: body);
    } catch (_) {
      // Offline or server down: the local state is the source of truth and
      // will be pushed again on the next login.
    }
  }

  /// Appends a row to the student's server-side activity log. Fire-and-forget.
  Future<void> logActivity(
    String action, [
    Map<String, dynamic>? metadata,
  ]) async {
    try {
      await _requestRaw(
        'POST',
        '/api/users/activity',
        body: {'action': action, if (metadata != null) 'metadata': metadata},
      );
    } catch (_) {
      // Never block the student's flow on telemetry.
    }
  }

  // Parent-child linking
  // Only APPROVED links: this is what a parent's dashboard is allowed to show.
  Future<List<dynamic>> getLinkedChildren() async {
    final result = await _requestRaw('GET', '/api/parent/children');
    return result is List ? result : const [];
  }

  /// Every link the parent has sent, each carrying its own `status`
  /// (pending/approved/rejected), so the parent's UI can show "waiting for
  /// approval" instead of a request that silently vanishes.
  Future<List<dynamic>> getParentLinks() async {
    final result = await _requestRaw('GET', '/api/parent/links');
    return result is List ? result : const [];
  }

  /// Sends a link request. The student must approve it before any of their
  /// data becomes visible — see [getLinkRequests] / [respondToLinkRequest].
  Future<Map<String, dynamic>> linkChild(String studentEmail) async {
    return _request(
      'POST',
      '/api/parent/link',
      body: {'studentEmail': studentEmail},
    );
  }

  Future<Map<String, dynamic>> unlinkChild(String studentId) async {
    final result = await _requestRaw('DELETE', '/api/parent/link/$studentId');
    return result is Map<String, dynamic> ? result : {};
  }

  /// Student side: incoming parent link requests still awaiting a decision.
  Future<List<dynamic>> getLinkRequests() async {
    final result = await _requestRaw('GET', '/api/parent/requests');
    return result is List ? result : const [];
  }

  /// Student side: approve or reject a pending parent link request.
  Future<Map<String, dynamic>> respondToLinkRequest(
    String requestId,
    bool approve,
  ) async {
    return _request(
      'POST',
      '/api/parent/requests/$requestId/${approve ? 'approve' : 'reject'}',
    );
  }

  /// Real top students by XP. Only accounts that have actually scored are
  /// returned, so an early/empty install gets an empty list rather than a
  /// table of zeroes — the screen shows an honest empty state for that.
  Future<List<dynamic>> getLeaderboard() async {
    final result = await _requestRaw('GET', '/api/users/leaderboard');
    return result is List ? result : const [];
  }

  // Attendance — sections (a teacher's own class roster).
  Future<Map<String, dynamic>> createSection({
    required String label,
    required String gradeLevel,
    String? subject,
  }) async {
    return _request(
      'POST',
      '/api/attendance/sections',
      body: {
        'label': label,
        'gradeLevel': gradeLevel,
        if (subject != null) 'subject': subject,
      },
    );
  }

  Future<List<dynamic>> getSections() async {
    final result = await _requestRaw('GET', '/api/attendance/sections');
    return result is List ? result : const [];
  }

  /// Student self-join via the classroom invite code (typed or scanned from
  /// the QR the teacher shows). Returns the joined section summary.
  Future<Map<String, dynamic>> joinSectionByInvite(String inviteCode) {
    return _request(
      'POST',
      '/api/attendance/sections/join',
      body: {'inviteCode': inviteCode.trim().toUpperCase()},
    );
  }

  Future<Map<String, dynamic>> addStudentToSection(
    String sectionId,
    String studentEmail, {
    String? rollNumber,
  }) async {
    return _request(
      'POST',
      '/api/attendance/sections/$sectionId/students',
      body: {
        'studentEmail': studentEmail,
        if (rollNumber != null) 'rollNumber': rollNumber,
      },
    );
  }

  Future<List<dynamic>> getSectionRoster(String sectionId) async {
    final result = await _requestRaw(
      'GET',
      '/api/attendance/sections/$sectionId/students',
    );
    return result is List ? result : const [];
  }

  Future<Map<String, dynamic>> removeStudentFromSection(
    String sectionId,
    String studentId,
  ) async {
    final result = await _requestRaw(
      'DELETE',
      '/api/attendance/sections/$sectionId/students/$studentId',
    );
    return result is Map<String, dynamic> ? result : {};
  }

  /// Student side: which enrolled section(s) currently have an open session,
  /// so the mark-attendance screen has something to point at without the
  /// student needing to know an internal session id.
  Future<List<dynamic>> getMyOpenAttendanceSessions() async {
    final result = await _requestRaw('GET', '/api/attendance/my-open-sessions');
    return result is List ? result : const [];
  }

  // Classroom — syllabus → AI notes, class tasks, notifications.
  /// Teacher posts a syllabus document; the backend converts it into
  /// structured AI notes (saved as a published TeacherNote + RAG index).
  Future<Map<String, dynamic>> postSyllabus({
    required String sectionId,
    required String title,
    required String syllabus,
  }) {
    return _request(
      'POST',
      '/api/classroom/syllabus',
      body: {'sectionId': sectionId, 'title': title, 'syllabus': syllabus},
    );
  }

  /// Tasks for the caller's classrooms. Teachers see all tasks with
  /// submission counts; students see their own status per task.
  Future<List<dynamic>> getClassroomTasks({String? sectionId}) async {
    final query = sectionId == null ? '' : '?sectionId=$sectionId';
    final result = await _requestRaw('GET', '/api/classroom/tasks$query');
    return result is List ? result : const [];
  }

  Future<Map<String, dynamic>> createClassTask({
    required String sectionId,
    required String title,
    String? description,
    DateTime? dueDate,
    int points = 0,
  }) {
    return _request(
      'POST',
      '/api/classroom/tasks',
      body: {
        'sectionId': sectionId,
        'title': title,
        if (description != null) 'description': description,
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'points': points,
      },
    );
  }

  Future<Map<String, dynamic>> deleteClassTask(String taskId) async {
    final result = await _requestRaw('DELETE', '/api/classroom/tasks/$taskId');
    return result is Map<String, dynamic> ? result : {};
  }

  /// Student flips their own submission: 'done' or 'pending'.
  Future<Map<String, dynamic>> submitClassTask(
    String taskId, {
    required String status,
  }) {
    return _request(
      'POST',
      '/api/classroom/tasks/$taskId/submit',
      body: {'status': status},
    );
  }

  /// In-app notification stream for the signed-in user.
  Future<Map<String, dynamic>> getNotifications() async {
    final result = await _requestRaw('GET', '/api/classroom/notifications');
    return result is Map<String, dynamic>
        ? result
        : {'items': const [], 'unreadCount': 0};
  }

  /// Marks one notification read, or all when [id] is null.
  Future<void> markNotificationsRead({String? id}) async {
    await _requestRaw(
      'POST',
      '/api/classroom/notifications/read',
      body: {if (id != null) 'id': id},
    );
  }

  // Attendance — sessions.
  Future<Map<String, dynamic>> startAttendanceSession(
    String sectionId,
    String subject, {
    double? lat,
    double? lng,
    int radiusMeters = 75,
  }) async {
    return _request(
      'POST',
      '/api/attendance/sections/$sectionId/sessions',
      body: {
        'subject': subject,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'radiusMeters': radiusMeters,
      },
    );
  }

  /// Returns the currently valid rotating code (server rotates it as needed);
  /// the teacher screen calls this every ~20s to keep a fresh code on screen.
  Future<Map<String, dynamic>> getAttendanceCode(String sessionId) async {
    return _request('GET', '/api/attendance/sessions/$sessionId/code');
  }

  /// Full roster cross-referenced with who has actually marked in — what
  /// lets a teacher catch "marked present without checking."
  Future<Map<String, dynamic>> getAttendanceRoster(String sessionId) async {
    return _request('GET', '/api/attendance/sessions/$sessionId/roster');
  }

  /// Student side: submit the code shown by the teacher. Generates its own
  /// idempotency key so a retry on a dropped connection can never double-mark.
  /// [lat]/[lng] are the device-reported position; the server enforces the
  /// session's geo-fence when it has one.
  Future<Map<String, dynamic>> markAttendance(
    String sessionId,
    String code, {
    double? lat,
    double? lng,
    bool? isMocked,
  }) async {
    return _request(
      'POST',
      '/api/attendance/sessions/$sessionId/mark',
      body: {
        'code': code,
        'idempotencyKey': _uuid.v4(),
        'clientMarkedAt': DateTime.now().toUtc().toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        // Android reports when a fix came from a mock-location app. Honest
        // clients forward it; the server treats a missing value as unknown.
        if (isMocked != null) 'isMocked': isMocked,
      },
    );
  }

  Future<Map<String, dynamic>> overrideAttendance(
    String sessionId, {
    required String studentId,
    required String status,
    required String reason,
  }) async {
    return _request(
      'POST',
      '/api/attendance/sessions/$sessionId/override',
      body: {'studentId': studentId, 'status': status, 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> closeAttendanceSession(String sessionId) async {
    return _request('POST', '/api/attendance/sessions/$sessionId/close');
  }

  /// Teacher's offline-hotspot flush: peer-to-peer marks collected on the
  /// teacher's phone (no internet in class) are re-validated server-side and
  /// stored in one call. Server acks come back in request order.
  Future<Map<String, dynamic>> attendanceBatch(
    String sessionId,
    List<Map<String, dynamic>> marks,
  ) async {
    return _request(
      'POST',
      '/api/attendance/sessions/$sessionId/batch',
      body: {'marks': marks},
    );
  }

  /// Offline outbox flush: notes and quiz results taken without connectivity,
  /// answered per-item so the client drops exactly what landed.
  Future<Map<String, dynamic>> syncQueue(
    List<Map<String, dynamic>> items,
  ) async {
    return _request('POST', '/api/sync/queue', body: {'items': items});
  }

  Future<Map<String, dynamic>> getMyAttendanceHistory({int days = 30}) async {
    return _request('GET', '/api/attendance/my-history?days=$days');
  }

  Future<Map<String, dynamic>> getChildAttendanceHistory(
    String studentId, {
    int days = 30,
  }) async {
    return _request(
      'GET',
      '/api/attendance/child/$studentId/history?days=$days',
    );
  }

  /// Bulk roster import: one "email,rollNumber" per line.
  Future<Map<String, dynamic>> importSectionCsv(
    String sectionId,
    String csv,
  ) async {
    return _request(
      'POST',
      '/api/attendance/sections/$sectionId/students/bulk',
      body: {'csv': csv},
    );
  }

  /// Parent digest: per-day rollup for every approved child.
  Future<Map<String, dynamic>> getParentDigest({int days = 7}) async {
    return _request('GET', '/api/attendance/digest?days=$days');
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    if (_token == null) return {'error': 'Please sign in first.'};
    try {
      final uri = Uri.parse('$baseUrl/api/users/avatar');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_token'
        ..headers['X-Device-Id'] = await _getDeviceId()
        ..headers['X-Device-Name'] = _deviceName
        ..files.add(await http.MultipartFile.fromPath('avatar', filePath));
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 401) {
        await _clearSession();
        return {'error': 'Session expired. Please login again.'};
      }
      final decoded = await _decodeResponse(
        http.Response(body, streamed.statusCode, headers: streamed.headers),
      );
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : {'error': 'Unexpected upload response. Please try again.'};
    } catch (e) {
      return {'error': 'Upload failed. Please check your connection.'};
    }
  }

  Future<Map<String, dynamic>> uploadOrgLogo(String filePath) async {
    if (_token == null) return {'error': 'Please sign in first.'};
    try {
      final uri = Uri.parse('$baseUrl/api/users/org-logo');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_token'
        ..headers['X-Device-Id'] = await _getDeviceId()
        ..headers['X-Device-Name'] = _deviceName
        ..files.add(await http.MultipartFile.fromPath('logo', filePath));
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 401) {
        await _clearSession();
        return {'error': 'Session expired. Please login again.'};
      }
      final decoded = await _decodeResponse(
        http.Response(body, streamed.statusCode, headers: streamed.headers),
      );
      final map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{
              'error': 'Unexpected upload response. Please try again.',
            };
      if (map['error'] == null) _syncOrgBranding(map);
      return map;
    } catch (e) {
      return {'error': 'Upload failed. Please check your connection.'};
    }
  }

  Future<Map<String, dynamic>> getTeacherHome() async {
    final result = await _request('GET', '/api/classroom/teacher/home');
    if (result['error'] == null) _syncOrgBranding(result);
    return result;
  }

  Future<Map<String, dynamic>> getInstituteLiveClasses() async {
    return _request('GET', '/api/admin/live-classes');
  }

  Future<Map<String, dynamic>> getLiveStatus(String sectionId) async {
    return _request('GET', '/api/classroom/sections/$sectionId/live');
  }

  Future<Map<String, dynamic>> getMyLiveStatus() async {
    return _request('GET', '/api/classroom/my-live');
  }

  Future<Map<String, dynamic>> startLiveClass(
    String sectionId, {
    required String title,
    required bool recordingAllowed,
  }) async {
    return _request(
      'POST',
      '/api/classroom/sections/$sectionId/live/start',
      body: {'title': title, 'recordingAllowed': recordingAllowed},
    );
  }

  Future<Map<String, dynamic>> endLiveClass(String liveSessionId) async {
    return _request('POST', '/api/classroom/live/$liveSessionId/end');
  }

  Future<Map<String, dynamic>> getLiveClassToken(String liveSessionId) async {
    return _request('POST', '/api/classroom/live/$liveSessionId/token');
  }

  Future<Map<String, dynamic>> getAdminUsers({String query = ''}) async {
    final q = query.trim();
    return _request(
      'GET',
      '/api/admin/users${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}',
    );
  }

  Future<Map<String, dynamic>> createImAccount({
    required String name,
    required String email,
    required String password,
    required List<String> permissions,
  }) async {
    return _request(
      'POST',
      '/api/admin/create-im',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'permissions': permissions,
      },
    );
  }

  Future<Map<String, dynamic>> assignUserRole(
    String userId, {
    required String role,
    List<String> permissions = const [],
  }) async {
    return _request(
      'PATCH',
      '/api/admin/users/$userId/role',
      body: {'role': role, if (role == 'im') 'permissions': permissions},
    );
  }

  Future<Map<String, dynamic>> getParentLiveStatus() async {
    return _request('GET', '/api/parent/live');
  }

  Future<Map<String, dynamic>> getParentActivity() async {
    return _request('GET', '/api/parent/activity');
  }

  Future<Map<String, dynamic>> getParentAiDigest() async {
    return _request('GET', '/api/ai/parent-digest');
  }

  Future<Map<String, dynamic>> getParentRanks() async {
    return _request('GET', '/api/parent/ranks');
  }

  Future<Map<String, dynamic>> getParentLiveHistory() async {
    return _request('GET', '/api/parent/live-history');
  }
}
