import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:nexus_edu/core/network/api_client.dart';
import 'package:nexus_edu/core/security/aes_encryption_service.dart';
import 'package:nexus_edu/core/security/nonce_service.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Encrypted + nonce-protected channel on top of [ApiClient].
/// Request: `{"cipher": "<base64(iv+cipher)>"}`, headers `X-Nonce`/`X-Timestamp`/`X-Body-Hash`.
/// Response: server returns `{"cipher": "..."}` with same nonce echo — client decrypts + validates.
/// Falls back to plain if server replies without `cipher` (backward compat).
class SecureChannel {
  SecureChannel({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Result<dynamic>> postEncrypted(
    String path, {
    Map<String, dynamic>? body,
    bool requireNonceEcho = true,
  }) async {
    final plainJson = body == null ? '{}' : jsonEncode(body);
    final nonce = NonceService.generate();
    final ts = NonceService.timestamp();
    final bodyHash = sha256.convert(utf8.encode(plainJson)).toString();

    try {
      // Wrap + encrypt
      final wrap = await AesEncryptionService.wrap(plainJson, nonce: nonce, ts: ts);
      final encBody = {'cipher': wrap['cipher'], '_nonce': nonce, '_ts': ts, '_hash': bodyHash};

      // Send as JSON with extra headers for server validation
      final res = await _client.send('POST', path, body: encBody);
      final decoded = _client.decodeResponse(res);
      if (decoded is Map && decoded['error'] != null) {
        return Failure(decoded['error'].toString(), error: decoded, kind: FailureKind.server);
      }

      // If server responded encrypted
      if (decoded is Map && decoded['cipher'] is String) {
        try {
          final plain = await AesEncryptionService.unwrap(decoded['cipher'] as String, expectedNonce: nonce);
          final data = jsonDecode(plain);
          return Success(data);
        } catch (e) {
          return Failure('Decrypt failed', error: e, kind: FailureKind.server);
        }
      }

      // Plain fallback (server not yet upgraded)
      return Success(decoded);
    } catch (e) {
      return Failure('Secure channel failed', error: e, kind: FailureKind.network);
    }
  }

  Future<Result<dynamic>> getEncrypted(String path) async {
    final nonce = NonceService.generate();
    // final ts = NonceService.timestamp(); // for future GET signing
    try {
      final res = await _client.send('GET', path);
      final decoded = _client.decodeResponse(res);
      if (decoded is Map && decoded['error'] != null) {
        return Failure(decoded['error'].toString(), error: decoded);
      }
      if (decoded is Map && decoded['cipher'] is String) {
        final plain = await AesEncryptionService.unwrap(decoded['cipher'] as String, expectedNonce: nonce);
        return Success(jsonDecode(plain));
      }
      return Success(decoded);
    } catch (e) {
      return Failure(e.toString(), error: e, kind: FailureKind.network);
    }
  }
}
