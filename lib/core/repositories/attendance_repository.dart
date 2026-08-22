import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Attendance + sections — fixes empty vs error (`List?` null = failure)
class AttendanceRepository {
  AttendanceRepository({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Result<List<dynamic>>> getSections() async {
    final res = await _client.requestResult('GET', '/api/attendance/sections');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return Failure('Unexpected response', error: d);
  }

  Future<Result<List<dynamic>>> getMySections() async {
    final res = await _client.requestResult('GET', '/api/attendance/my-sections');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> createSection({
    required String label,
    required String gradeLevel,
    String? subject,
    String? semester,
  }) async {
    final res = await _client.requestResult('POST', '/api/attendance/sections', body: {
      'label': label,
      'gradeLevel': gradeLevel,
      if (subject != null) 'subject': subject,
      if (semester != null) 'semester': semester,
    });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> joinSectionByInvite(String code) async {
    final res = await _client.requestResult('POST', '/api/attendance/sections/join',
        body: {'inviteCode': code.trim().toUpperCase()});
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<List<dynamic>>> getSectionRoster(String sectionId) async {
    final res = await _client.requestResult('GET', '/api/attendance/sections/$sectionId/students');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> addStudentToSection(
    String sectionId, String email, {String? rollNumber}) async {
    final res = await _client.requestResult(
        'POST', '/api/attendance/sections/$sectionId/students',
        body: {'studentEmail': email, if (rollNumber != null) 'rollNumber': rollNumber});
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<void>> removeStudentFromSection(String sectionId, String studentId) async {
    final res = await _client
        .requestResult('DELETE', '/api/attendance/sections/$sectionId/students/$studentId');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    return const Success(null);
  }

  Future<Result<List<dynamic>>> getMyOpenSessions() async {
    final res = await _client.requestResult('GET', '/api/attendance/my-open-sessions');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> startSession(
    String sectionId,
    String subject, {
    double? lat,
    double? lng,
    int radiusMeters = 75,
  }) async {
    final res = await _client.requestResult('POST', '/api/attendance/sections/$sectionId/sessions',
        body: {
          'subject': subject,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'radiusMeters': radiusMeters,
        });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> getAttendanceCode(String sessionId) async {
    final res = await _client.requestResult('GET', '/api/attendance/sessions/$sessionId/code');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> getAttendanceRoster(String sessionId) async {
    final res = await _client.requestResult('GET', '/api/attendance/sessions/$sessionId/roster');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> markAttendance(
    String sessionId,
    String code, {
    double? lat,
    double? lng,
    bool? isMocked,
  }) async {
    final res = await _client.requestResult('POST', '/api/attendance/sessions/$sessionId/mark',
        body: {
          'code': code,
          'idempotencyKey': DateTime.now().microsecondsSinceEpoch.toString(),
          'clientMarkedAt': DateTime.now().toUtc().toIso8601String(),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (isMocked != null) 'isMocked': isMocked,
        });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> closeSession(String sessionId) async {
    final res = await _client.requestResult('POST', '/api/attendance/sessions/$sessionId/close');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> importCsv(String sectionId, String csv) async {
    final res = await _client.requestResult(
        'POST', '/api/attendance/sections/$sectionId/students/bulk',
        body: {'csv': csv});
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }
}
