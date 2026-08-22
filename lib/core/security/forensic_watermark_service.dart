import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Forensic watermark — C++ (fast) + Dart fallback. Used by LiveClass.
class ForensicWatermarkService {
  static const _ch = MethodChannel('com.nexus.edu/security');

  /// 8-char hash via C++ `nx_watermark_hash` or Dart SHA256 fallback.
  static Future<String> hash(String userId, String sessionId, int ts) async {
    final input = '$userId|$sessionId|$ts';
    try {
      final h = await _ch.invokeMethod<String>('watermarkHash', {'input': input});
      if (h != null && h.length == 8) return h;
    } catch (_) {}
    // Fallback: Dart SHA256 first 8 hex
    return sha256.convert(utf8.encode(input)).toString().substring(0, 8);
  }

  /// Full display string: `a7f3 · Aarav · Sunrise · 11:42 AM`
  static Future<String> display({
    required String userId,
    required String sessionId,
    required String userName,
    String? orgName,
    DateTime? now,
  }) async {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final h = await hash(userId, sessionId, ts);
    final t = now ?? DateTime.now();
    final time = '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
    final org = orgName?.trim().isNotEmpty == true ? ' · $orgName' : '';
    final name = userName.trim().isEmpty ? 'Student' : userName.trim();
    return '$h · $name$org · $time';
  }

  /// For live class tiled background, generate 3 variants with rotated positions.
  static Future<List<String>> tiledVariants({
    required String userId,
    required String sessionId,
    required String userName,
    String? orgName,
  }) async {
    final base = await display(userId: userId, sessionId: sessionId, userName: userName, orgName: orgName);
    return [base, base, base];
  }
}
