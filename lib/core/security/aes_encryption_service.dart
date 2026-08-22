import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexus_edu/core/security/nonce_service.dart';

/// AES-256-GCM authenticated encryption for client<->server payloads.
/// Key is 32 bytes derived from secure storage (or fetched from server on
/// first login and cached). Never hard-coded in Dart. Re-key supported.
class AesEncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyKey = 'aes_channel_key_b64';
  static const _keyHashKey = 'aes_channel_key_hash';
  static enc.Encrypter? _encrypter;
  static String? _cachedKeyB64;

  /// Derive or fetch session key. If [serverProvidedB64] given (after HTTPS
  /// handshake), store it. Otherwise load cached or derive fallback from
  /// device seed + token hash (forward-compatible until server pushes real key).
  static Future<String> ensureKey({String? serverProvidedB64}) async {
    if (serverProvidedB64 != null) {
      await _storage.write(key: _keyKey, value: serverProvidedB64);
      final hash = sha256.convert(base64Decode(serverProvidedB64)).toString();
      await _storage.write(key: _keyHashKey, value: hash);
      _cachedKeyB64 = serverProvidedB64;
      _encrypter = null;
      return serverProvidedB64;
    }
    if (_cachedKeyB64 != null) return _cachedKeyB64!;
    final cached = await _storage.read(key: _keyKey);
    if (cached != null && cached.isNotEmpty) {
      _cachedKeyB64 = cached;
      return cached;
    }
    // SEC-R7 fix: fail-closed — no insecure time-based fallback. Only server-provided key is persisted.
    if (serverProvidedB64 == null && _cachedKeyB64 == null) throw Exception('No AES key - fetch from /api/ws/hello first');
    throw Exception('No AES key - fetch from /api/ws/hello first');
  }

  static Future<enc.Encrypter> _getEncrypter() async {
    if (_encrypter != null) return _encrypter!;
    final keyB64 = await ensureKey();
    final bytes = base64Decode(keyB64.trim());
    if(bytes.length!=32) throw Exception('Invalid key length');
    final key = enc.Key(bytes);
    // Use AES GCM via SIV mode emulation: encrypt pkg uses AES/GCM/NoPadding
    // on Android via PointyCastle; we use AES/CBC + HMAC for compatibility
    // if GCM not available, but prefer GCM. Here we use enc.AES with GCM.
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return _encrypter!;
  }

  /// Encrypts JSON string -> base64( iv(12) + ciphertext + tag(16) ) via GCM.
  /// For CBC fallback, returns base64( iv + ciphertext ) with HMAC in separate header.
  static Future<String> encrypt(String plainJson) async {
    final encrypter = await _getEncrypter();
    final iv = enc.IV.fromSecureRandom(12);
    final encrypted = encrypter.encrypt(plainJson, iv: iv);
    // GCM: encrypted.bytes already includes tag at end; prepend iv.
    final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return base64Encode(combined);
  }

  static Future<String> decrypt(String b64Cipher) async {
    final encrypter = await _getEncrypter();
    final combined = base64Decode(b64Cipher);
    if (combined.length < 12) throw Exception('cipher too short');
    final iv = enc.IV(combined.sublist(0, 12));
    final cipherBytes = combined.sublist(12);
    final encrypted = enc.Encrypted(cipherBytes);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// Wraps payload with nonce + timestamp before encrypt.
  static Future<Map<String, String>> wrap(String jsonBody, {required String nonce, required String ts}) async {
    final envelope = jsonEncode({'nonce': nonce, 'ts': ts, 'data': jsonBody});
    final cipher = await encrypt(envelope);
    final bodyHash = sha256.convert(utf8.encode(jsonBody)).toString();
    return {
      'X-Encrypted': '1',
      'X-Nonce': nonce,
      'X-Timestamp': ts,
      'X-Body-Hash': bodyHash,
      'cipher': cipher,
    };
  }

  /// Unwraps and validates nonce.
  static Future<String> unwrap(String cipher, {required String expectedNonce}) async {
    final envelopeJson = await decrypt(cipher);
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final nonce = envelope['nonce']?.toString() ?? '';
    final ts = envelope['ts']?.toString() ?? '';
    final data = envelope['data']?.toString() ?? '';
    final ok = NonceService.validateResponse(
      requestNonce: expectedNonce,
      responseNonce: nonce,
      responseTs: ts,
    );
    if (!ok) throw Exception('nonce/timestamp validation failed');
    return data;
  }

  static Future<void> clearKey() async {
    await _storage.delete(key: _keyKey);
    await _storage.delete(key: _keyHashKey);
    _cachedKeyB64 = null;
    _encrypter = null;
  }
}
