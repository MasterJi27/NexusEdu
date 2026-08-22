import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/security/forensic_watermark_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';

/// BLU: watermark string + moving corner index. Pure, testable.
class LiveClassWatermarkState {
  const LiveClassWatermarkState({required this.text, this.corner = 0});
  final String text;
  /// 0=bottomRight, 1=bottomLeft, 2=topRight, 3=topLeft
  final int corner;
}

class LiveClassWatermarkNotifier extends AsyncNotifier<LiveClassWatermarkState> {
  Timer? _moveTimer;
  Timer? _refreshTimer;

  @override
  Future<LiveClassWatermarkState> build() async => const LiveClassWatermarkState(text: 'Nexus Edu · LIVE');

  Future<void> init({required String liveSessionId, required String userId, required String userName, String? orgName}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final text = await ForensicWatermarkService.display(
        userId: userId,
        sessionId: liveSessionId,
        userName: userName,
        orgName: orgName,
      );
      return LiveClassWatermarkState(text: text, corner: 0);
    });
    // Refresh text every 60s (time tick), move corner every 7s
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final cur = state.value;
      if (cur == null) return;
      final t = await ForensicWatermarkService.display(userId: userId, sessionId: liveSessionId, userName: userName, orgName: orgName);
      state = AsyncValue.data(LiveClassWatermarkState(text: t, corner: cur.corner));
    });
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      final cur = state.value;
      if (cur == null) return;
      state = AsyncValue.data(LiveClassWatermarkState(text: cur.text, corner: (cur.corner + 1) % 4));
    });
    ref.onDispose(() {
      _moveTimer?.cancel();
      _refreshTimer?.cancel();
    });
  }
}

final liveClassWatermarkProvider = AsyncNotifierProvider<LiveClassWatermarkNotifier, LiveClassWatermarkState>(LiveClassWatermarkNotifier.new);

/// BLU: recording policy — FLAG_SECURE + internal record flag.
class LiveClassRecordingPolicy {
  const LiveClassRecordingPolicy({required this.recordingAllowed, required this.flagSecure});
  final bool recordingAllowed;
  /// true = add FLAG_SECURE (block OS screen record), false = allow
  final bool flagSecure;
}

final liveClassRecordingPolicyProvider = Provider.family<LiveClassRecordingPolicy, bool>((ref, recordingAllowed) {
  return LiveClassRecordingPolicy(recordingAllowed: recordingAllowed, flagSecure: !recordingAllowed);
});

/// BLU: anti-record — screen capture callback registration.
class LiveClassAntiRecordNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setCaptured(bool v) => state = v;
}

final liveClassAntiRecordProvider = NotifierProvider<LiveClassAntiRecordNotifier, bool>(LiveClassAntiRecordNotifier.new);
