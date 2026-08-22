import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Thin HTTP client — single source for headers, timeouts, device-id and
/// response decoding. Inject `http.Client` for tests (`MockClient`).
class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nexus-edu-backend.azurewebsites.net',
  );

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static const _uuid = Uuid();
  static const _authTokenKey = 'auth_token';
  static const _deviceIdKey = 'auth_device_id';

  Future<String?> _readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('ApiClient: read $key failed: $e');
      return null;
    }
  }

  Future<String> _getDeviceId() async {
    final existing = await _readSecure(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    // Fallback to prefs if secure storage unavailable (dev emulator)
    try {
      final prefs = await SharedPreferences.getInstance();
      final fallback = prefs.getString(_deviceIdKey);
      if (fallback != null && fallback.isNotEmpty) return fallback;
    } catch (_) {}
    final created = _uuid.v4();
    try {
      await _storage.write(key: _deviceIdKey, value: created);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_deviceIdKey, created);
      } catch (_) {}
    }
    return created;
  }

  Future<Map<String, String>> buildHeaders() async {
    final token = await _readSecure(_authTokenKey);
    final deviceId = await _getDeviceId();
    return {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId,
      'X-Device-Name': 'NexusEdu ${defaultTargetPlatform.name}',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Shared timeout per method.
  Duration _timeoutFor(String method) =>
      method == 'POST' ? const Duration(seconds: 60) : const Duration(seconds: 30);

  Future<http.Response> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await buildHeaders();
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(_timeoutFor(method));
      case 'POST':
        return _client.post(uri, headers: headers, body: encoded).timeout(_timeoutFor(method));
      case 'PUT':
        return _client.put(uri, headers: headers, body: encoded).timeout(_timeoutFor(method));
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: encoded).timeout(_timeoutFor(method));
      default:
        return _client.delete(uri, headers: headers).timeout(_timeoutFor(method));
    }
  }

  /// Decodes [response] to dynamic or `{'error': ...}` map.
  /// Does NOT clear session — caller decides `kind` mapping.
  dynamic decodeResponse(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return response.statusCode >= 400
          ? {'error': _genericError(response.statusCode)}
          : <String, dynamic>{};
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return {
        'error': response.statusCode >= 400
            ? _genericError(response.statusCode)
            : 'Unexpected server response. Please try again.',
      };
    }
    if (response.statusCode >= 400) {
      if (decoded is Map) {
        final msg = decoded['error'] ?? decoded['message'];
        if (msg != null) return {'error': msg.toString()};
      }
      return {'error': _genericError(response.statusCode)};
    }
    return decoded;
  }

  String _genericError(int code) => code == 401
      ? 'Session expired. Please login again.'
      : 'Server error ($code). Please try again.';

  /// Convenience: send + decode + Result wrapping.
  Future<Result<dynamic>> requestResult(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await send(method, path, body: body);
      final decoded = decodeResponse(res);
      if (decoded is Map && decoded['error'] != null) {
        final kind = res.statusCode == 401
            ? FailureKind.auth
            : res.statusCode >= 500
                ? FailureKind.server
                : FailureKind.unknown;
        return Failure(decoded['error'].toString(), error: decoded, kind: kind);
      }
      return Success(decoded);
    } catch (e) {
      return Failure(
        'Connection failed. Please check your internet.',
        error: e,
        kind: FailureKind.network,
      );
    }
  }

  /// Multipart upload helper — shares headers + 401 handling pattern.
  Future<Result<Map<String, dynamic>>> uploadMultipart({
    required String path,
    required String fileField,
    required String filePath,
  }) async {
    try {
      final token = await _readSecure(_authTokenKey);
      if (token == null) {
        return const Failure('Please sign in first.', kind: FailureKind.auth);
      }
      final deviceId = await _getDeviceId();
      final uri = Uri.parse('$baseUrl$path');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['X-Device-Id'] = deviceId
        ..headers['X-Device-Name'] = 'NexusEdu ${defaultTargetPlatform.name}'
        ..files.add(await http.MultipartFile.fromPath(fileField, filePath));
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      final decoded = decodeResponse(
        http.Response(body, streamed.statusCode, headers: streamed.headers),
      );
      if (decoded is Map && decoded['error'] != null) {
        return Failure(decoded['error'].toString(), error: decoded);
      }
      if (decoded is Map<String, dynamic>) return Success(decoded);
      if (decoded is Map) return Success(Map<String, dynamic>.from(decoded));
      return Success(<String, dynamic>{});
    } catch (e) {
      return Failure('Upload failed. Please check your connection.', error: e, kind: FailureKind.network);
    }
  }

  void close() => _client.close();
}
