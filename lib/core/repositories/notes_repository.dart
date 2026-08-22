import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Notes — fixes `_requestRaw` swallow: null = failure, [] = real empty.
class NotesRepository {
  NotesRepository({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Result<List<dynamic>>> getNotes() async {
    final res = await _client.requestResult('GET', '/api/notes');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final data = (res as Success).data;
    if (data is List) return Success(data);
    if (data == null) return const Success([]);
    return Failure('Unexpected response', error: data);
  }

  Future<Result<Map<String, dynamic>>> createNote({
    required String title,
    required String content,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _client.requestResult('POST', '/api/notes', body: {
      'title': title,
      'content': content,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> updateNote({
    required String id,
    required String title,
    required String content,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _client.requestResult('PUT', '/api/notes/$id', body: {
      'title': title,
      'content': content,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<void>> deleteNote(String id) async {
    final res = await _client.requestResult('DELETE', '/api/notes/$id');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    return const Success(null);
  }

  // Teacher notes — classroom syllabus notes
  Future<Result<List<dynamic>>> getTeacherNotes({String? gradeLevel, String? subject}) async {
    final q = <String>[];
    if (gradeLevel != null) q.add('gradeLevel=${Uri.encodeQueryComponent(gradeLevel)}');
    if (subject != null) q.add('subject=${Uri.encodeQueryComponent(subject)}');
    final qs = q.isEmpty ? '' : '?${q.join('&')}';
    final res = await _client.requestResult('GET', '/api/teacher-notes$qs');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> createTeacherNote({
    required String title,
    required String content,
    required String gradeLevel,
    required String subject,
    String? topic,
  }) async {
    final res = await _client.requestResult('POST', '/api/teacher-notes', body: {
      'title': title,
      'content': content,
      'gradeLevel': gradeLevel,
      'subject': subject,
      if (topic != null) 'topic': topic,
    });
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }
}
