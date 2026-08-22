import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

class ClassroomRepository {
  ClassroomRepository({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Result<List<dynamic>>> getTasks({String? sectionId}) async {
    final q = sectionId == null ? '' : '?sectionId=$sectionId';
    final res = await _client.requestResult('GET', '/api/classroom/tasks$q');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> createTask({
    required String sectionId,
    required String title,
    String? description,
    DateTime? dueDate,
    int points = 0,
  }) async {
    final res = await _client.requestResult('POST', '/api/classroom/tasks', body: {
      'sectionId': sectionId,
      'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
      'points': points,
    });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<void>> deleteTask(String taskId) async {
    final res = await _client.requestResult('DELETE', '/api/classroom/tasks/$taskId');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    return const Success(null);
  }

  Future<Result<Map<String, dynamic>>> submitTask(
    String taskId, {
    required String status,
    String? content,
  }) async {
    final res = await _client.requestResult('POST', '/api/classroom/tasks/$taskId/submit',
        body: {'status': status, if (content != null) 'content': content});
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> getLiveStatus(String sectionId) async {
    final res = await _client.requestResult('GET', '/api/classroom/sections/$sectionId/live');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> getMyLiveStatus() async {
    final res = await _client.requestResult('GET', '/api/classroom/my-live');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> startLiveClass(
    String sectionId, {
    required String title,
    required bool recordingAllowed,
  }) async {
    final res = await _client.requestResult(
        'POST', '/api/classroom/sections/$sectionId/live/start',
        body: {'title': title, 'recordingAllowed': recordingAllowed});
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> getTeacherHome() async {
    final res = await _client.requestResult('GET', '/api/classroom/teacher/home');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> getNotifications() async {
    final res = await _client.requestResult('GET', '/api/classroom/notifications');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is Map<String, dynamic>) return Success(d);
    if (d is Map) return Success(Map<String, dynamic>.from(d));
    return const Success({'items': [], 'unreadCount': 0});
  }
}
