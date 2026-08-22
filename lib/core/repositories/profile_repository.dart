import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/utils/result.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Result<Map<String, dynamic>>> getProfile() async {
    final res = await _client.requestResult('GET', '/api/users/profile');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<Map<String, dynamic>>> updateProfile(Map<String, dynamic> body) async {
    final res = await _client.requestResult('PUT', '/api/users/profile', body: body);
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }

  Future<Result<List<dynamic>>> getLeaderboard() async {
    final res = await _client.requestResult('GET', '/api/users/leaderboard');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> uploadAvatar(String path) async {
    final res = await _client.uploadMultipart(path: '/api/users/avatar', fileField: 'avatar', filePath: path);
    return res;
  }

  Future<Result<Map<String, dynamic>>> uploadOrgLogo(String path) async {
    final res = await _client.uploadMultipart(path: '/api/users/org-logo', fileField: 'logo', filePath: path);
    return res;
  }

  Future<Result<List<dynamic>>> getDeviceSessions() async {
    final res = await _client.requestResult('GET', '/api/auth/sessions');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<void>> revokeSession(String id) async {
    final res = await _client.requestResult('DELETE', '/api/auth/sessions/$id');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    return const Success(null);
  }

  Future<Result<List<dynamic>>> getLinkRequests() async {
    final res = await _client.requestResult('GET', '/api/parent/requests');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    if (d is List) return Success(d);
    return const Success([]);
  }

  Future<Result<Map<String, dynamic>>> respondToLinkRequest(String requestId, bool approve) async {
    final res = await _client.requestResult(
        'POST', '/api/parent/requests/$requestId/${approve ? 'approve' : 'reject'}');
    if (res is Failure) return Failure(res.message, error: res.error, kind: res.kind);
    final d = (res as Success).data;
    return Success(d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map));
  }
}
