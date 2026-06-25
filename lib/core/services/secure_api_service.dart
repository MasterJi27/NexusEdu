import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SecureApiService {
  static final SecureApiService _instance = SecureApiService._();
  factory SecureApiService() => _instance;
  SecureApiService._();

  // Change this to your deployed proxy URL
  static const String _baseUrl = 'http://10.0.2.2:3000';
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userName;

  bool get isLoggedIn => _accessToken != null;
  String get userName => _userName ?? 'Guest';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('proxy_access_token');
    _refreshToken = prefs.getString('proxy_refresh_token');
    _userId = prefs.getString('proxy_user_id');
    _userName = prefs.getString('proxy_user_name');
  }

  Future<void> _saveTokens(String accessToken, String refreshToken, String userId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userId = userId;
    _userName = name;
    await prefs.setString('proxy_access_token', accessToken);
    await prefs.setString('proxy_refresh_token', refreshToken);
    await prefs.setString('proxy_user_id', userId);
    await prefs.setString('proxy_user_name', name);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userName = null;
    await prefs.remove('proxy_access_token');
    await prefs.remove('proxy_refresh_token');
    await prefs.remove('proxy_user_id');
    await prefs.remove('proxy_user_name');
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['accessToken'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('proxy_access_token', _accessToken!);
        return true;
      }
    } catch (_) {}
    await _clearTokens();
    return false;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body}) async {
    try {
      Uri uri = Uri.parse('$_baseUrl$path');
      http.Response response;

      if (method == 'GET') {
        response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
      } else if (method == 'POST') {
        response = await http.post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 60));
      } else if (method == 'PUT') {
        response = await http.put(uri, headers: _headers, body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 30));
      } else {
        response = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _request(method, path, body: body);
        }
        return {'error': 'Session expired. Please login again.'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Connection failed. Please check your internet.'};
    }
  }

  // Auth
  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    final result = await _request('POST', '/api/auth/signup', body: {
      'name': name,
      'email': email,
      'password': password,
    });
    if (result['accessToken'] != null) {
      await _saveTokens(result['accessToken'], result['refreshToken'], result['user']['id'], result['user']['name']);
    }
    return result;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _request('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    if (result['accessToken'] != null) {
      await _saveTokens(result['accessToken'], result['refreshToken'], result['user']['id'], result['user']['name']);
    }
    return result;
  }

  Future<void> logout() async {
    await _request('POST', '/api/auth/logout');
    await _clearTokens();
  }

  // AI Features
  Future<String> chat(String prompt, {String systemPrompt = ''}) async {
    final result = await _request('POST', '/api/ai/chat', body: {
      'prompt': prompt,
      'systemPrompt': systemPrompt,
    });
    return result['result'] ?? result['error'] ?? 'Failed to get response';
  }

  Future<String> solveDoubt(String question, String subject) async {
    final result = await _request('POST', '/api/ai/solve-doubt', body: {
      'question': question,
      'subject': subject,
    });
    return result['result'] ?? result['error'] ?? 'Failed to solve doubt';
  }

  Future<String> generateQuiz(String topic, String subject, {int count = 5}) async {
    final result = await _request('POST', '/api/ai/generate-quiz', body: {
      'topic': topic,
      'subject': subject,
      'count': count,
    });
    return result['result'] ?? result['error'] ?? 'Failed to generate quiz';
  }

  Future<String> generateNotes(String topic, String subject) async {
    final result = await _request('POST', '/api/ai/generate-notes', body: {
      'topic': topic,
      'subject': subject,
    });
    return result['result'] ?? result['error'] ?? 'Failed to generate notes';
  }

  Future<String> solveMath(String problem) async {
    final result = await _request('POST', '/api/ai/solve-math', body: {
      'problem': problem,
    });
    return result['result'] ?? result['error'] ?? 'Failed to solve problem';
  }

  // User
  Future<Map<String, dynamic>> getProfile() async {
    return _request('GET', '/api/user/profile');
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? currentPassword, String? newPassword}) async {
    return _request('PUT', '/api/user/profile', body: {
      if (name != null) 'name': name,
      if (currentPassword != null) 'currentPassword': currentPassword,
      if (newPassword != null) 'newPassword': newPassword,
    });
  }
}
