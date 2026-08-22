import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:nexus_edu/core/security/forensic_watermark_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';

/// One-to-many live class over Agora: the teacher broadcasts camera + mic,
/// students watch as audience. Real video/audio — no mock, no placeholder —
/// but be honest about the recording control: FLAG_SECURE (applied below
/// when the teacher disallowed recording) blocks Android's own screenshot
/// and screen-recording APIs for this screen. It cannot stop a second
/// physical camera pointed at the device, and there is no app-level control
/// that can.
class LiveClassScreen extends StatefulWidget {
  const LiveClassScreen({
    super.key,
    required this.liveSessionId,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.userAccount,
    required this.isHost,
    required this.recordingAllowed,
    required this.title,
  });

  final String liveSessionId;
  final String appId;
  final String token;
  final String channelName;
  final String userAccount;
  final bool isHost;
  final bool recordingAllowed;
  final String title;

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _micMuted = false;
  bool _cameraOff = false;
  String? _error;
  bool _ending = false;

  // Cached video controllers: creating them inline in build() rebuilds the
  // platform-view element on every setState (mic/camera/board/share toggles),
  // which leaves stale dependents behind and trips Flutter's
  // "_dependents.isEmpty" assertion — any tap then crashes the screen.
  // Created lazily once the engine exists, reused across rebuilds.
  VideoViewController? _hostView;
  VideoViewController? _remoteView;
  int? _cachedRemoteUid;

  bool _chatOpen = false;
  int _chatUnread = 0;
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  Timer? _pollTimer;
  int? _chatCursor;
  bool _chatSending = false;

  bool _sharing = false;
  bool _boardOpen = false;
  final List<_BoardStroke> _boardStrokes = [];
  _BoardStroke? _activeStroke;
  Color _boardColor = Colors.white;
  bool _boardErasing = false;
  int? _boardCursor;
  Size _boardSize = Size.zero;

  /// True once the user is leaving or the state is disposed. Every async
  /// callback (engine events, poll timers, network replies) checks this
  /// before touching the tree: calling setState during a route teardown
  /// trips Flutter's `_dependents.isEmpty` assertion (red screen), and
  /// `mounted` alone does NOT cover that window.
  bool _leaving = false;

  String _forensicText = '';
  int _watermarkCorner = 0;
  Timer? _watermarkMoveTimer;
  Timer? _watermarkRefreshTimer;
  bool _screenCaptureDetected = false;

  /// setState that can never fire after the user left the class or the
  /// screen was disposed. The single gate for every async path.
  void _safeSetState(VoidCallback fn) {
    if (_leaving) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.recordingAllowed) {
      // Best-effort: blocks the OS's own screenshot/screen-record capture of
      // this screen. A second device filming the physical screen is outside
      // what any app can prevent — see forensic tiled watermark below.
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    } else {
      // Even when recordingAllowed, keep forensic watermark — internal Go recorder
      // captures server side; client still shows "LIVE" trace.
    }
    // Android 14+ screen capture detection via MethodChannel (see SecurityChannel)
    _listenScreenCapture();
    _initWatermark();
    _init();
  }

  Future<void> _initWatermark() async {
    final uid = SecureApiService().userId ?? widget.userAccount;
    final name = SecureApiService().userName;
    final org = SecureApiService().organizationName;
    try {
      final t = await ForensicWatermarkService.display(
        userId: uid,
        sessionId: widget.liveSessionId,
        userName: name,
        orgName: org,
      );
      if (!_leaving && mounted) setState(() => _forensicText = t);
    } catch (_) {
      _forensicText = 'Nexus Edu · LIVE';
    }
    // Move corner every 7s — cropping-resistant
    _watermarkMoveTimer?.cancel();
    _watermarkMoveTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (_leaving || !mounted) return;
      setState(() => _watermarkCorner = (_watermarkCorner + 1) % 4);
    });
    // Refresh time every 60s
    _watermarkRefreshTimer?.cancel();
    _watermarkRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_leaving || !mounted) return;
      try {
        final nt = await ForensicWatermarkService.display(userId: uid, sessionId: widget.liveSessionId, userName: name, orgName: org);
        if (!_leaving && mounted) setState(() => _forensicText = nt);
      } catch (_) {}
    });
  }

  void _listenScreenCapture() {
    const ch = MethodChannel('com.nexus.edu/security');
    // Android 14 registerScreenCaptureCallback will invoke this method from Kotlin
    ch.setMethodCallHandler((call) async {
      if (call.method == 'onScreenCaptured' && !_leaving && mounted) {
        setState(() => _screenCaptureDetected = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen capture detected — this live class is protected. Recording is logged.')),
        );
        // Auto-hide after 4s
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && !_leaving) setState(() => _screenCaptureDetected = false);
        });
        // Also report via SecureApiService for audit
        try {
          await SecureApiService().logActivity('SCREEN_CAPTURE_DETECTED', {'liveSessionId': widget.liveSessionId});
        } catch (_) {}
      }
    });
    // Ask native to register (no-op on <14)
    try { ch.invokeMethod('registerScreenCaptureCallback'); } catch (_) {}
  }

  Future<void> _init() async {
    // Android 13+ runtime permissions: the manifest declares camera/mic but
    // the OS still asks per-app. Without this the host's camera stays black
    // and Agora can throw. Request first, then join regardless — a denied
    // camera just means a black feed, never a crashed class.
    if (!kIsWeb) {
      final wanted = <Permission>[
        Permission.microphone,
        if (widget.isHost) Permission.camera,
      ];
      try {
        await Future.wait(wanted.map((p) => p.request().then((s) => s)));
      } catch (e) {
        // A permission-plugin hiccup must never block joining the class.
        debugPrint('Permission request failed: $e');
      }
    }
    final engine = createAgoraRtcEngine();
    // Assign the engine to state immediately: if the screen is popped while
    // the async join chain is still running, dispose() still sees it and
    // tears it down instead of orphaning the native engine.
    _engine = engine;
    try {
      await engine.initialize(RtcEngineContext(appId: widget.appId));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (_leaving) return;
            _safeSetState(() => _joined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (_leaving) return;
            _safeSetState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (_leaving) return;
            _safeSetState(() {
              if (_remoteUid == remoteUid) _remoteUid = null;
            });
          },
          onError: (err, msg) {
            if (_leaving) return;
            _safeSetState(() => _error = 'Connection issue: $msg');
          },
          // Screen share source died (e.g. the system took the projection
          // away): reset the toggle so the button reads as available again.
          onLocalVideoStateChanged: (source, state, reason) {
            if (_leaving || !_sharing) return;
            if (source == VideoSourceType.videoSourceScreen &&
                state == LocalVideoStreamState.localVideoStreamStateFailed) {
              _safeSetState(() => _sharing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Screen sharing stopped. The system ended the projection.',
                  ),
                ),
              );
            }
          },
          // User denied the MediaProjection consent: report and reset.
          onPermissionError: (permissionType) {
            if (_leaving || !_sharing) return;
            if (permissionType == PermissionType.screenCapture) {
              _safeSetState(() => _sharing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Screen sharing needs permission. Try again from the share button.',
                  ),
                ),
              );
            }
          },
        ),
      );

      await engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      // Everyone joins as a broadcaster so students can unmute and speak —
      // the token is PUBLISHER for every participant. Students simply don't
      // publish video (publishCameraTrack: false below).
      await engine.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );

      // Live-class audio routing. On iOS the engine can otherwise keep the
      // audio on the earpiece (the tiny call speaker), so students hear the
      // teacher very faintly; on Android this also covers Bluetooth/headset
      // and in-call volume quirks. Best-effort: a routing hiccup must never
      // block joining the class.
      try {
        await engine.setAudioScenario(
          AudioScenarioType.audioScenarioGameStreaming,
        );
      } catch (e) {
        debugPrint('setAudioScenario failed: $e');
      }

      if (widget.isHost) {
        await engine.enableVideo();
        await engine.startPreview();
      }

      await engine.joinChannelWithUserAccount(
        token: widget.token,
        channelId: widget.channelName,
        userAccount: widget.userAccount,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          // Students publish only their microphone: they can ask questions
          // live; their camera stays off.
          publishCameraTrack: widget.isHost,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // Route the class audio to the main loudspeaker (both platforms);
      // best-effort for the same reason as above.
      try {
        await engine.setDefaultAudioRouteToSpeakerphone(true);
      } catch (e) {
        debugPrint('setDefaultAudioRouteToSpeakerphone failed: $e');
      }

      if (_leaving) return;
      _safeSetState(() => _joined = true);
      // Chat and whiteboard sync poll while the class is open — regardless
      // of whether the panels are visible, so a teacher always notices a
      // student message (badge) and students always get the board strokes.
      _startPolling();
    } catch (e) {
      if (_leaving) return;
      // The engine may be half-initialized; release it so a disposed screen
      // never leaves a native engine running.
      unawaited(_teardownEngine());
      _safeSetState(
        () => _error =
            "Couldn't connect to the live class. Check your connection and try again.",
      );
    }
  }

  /// Starts the chat + whiteboard pollers. Runs forever while the class is
  /// open so unread chats surface as a badge and board strokes always sync.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollChat();
      _pollBoard();
    });
    _pollChat();
    _pollBoard();
  }

  /// Releases the native engine exactly once, tolerating any prior failure.
  Future<void> _teardownEngine() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      await engine.stopScreenCapture();
    } catch (_) {}
    try {
      await engine.leaveChannel();
    } catch (_) {}
    try {
      await engine.release();
    } catch (_) {}
  }

  Future<void> _toggleMic() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _micMuted = !_micMuted);
    await engine.muteLocalAudioStream(_micMuted);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _cameraOff = !_cameraOff);
    await engine.muteLocalVideoStream(_cameraOff);
  }

  /// Host-only screen share. Document scenario before joining is a no-op when
  /// called now (the engine is already joined), so it is set here too — the
  /// encoder picks it up when capture starts.
  Future<void> _toggleScreenShare() async {
    final engine = _engine;
    if (engine == null || !widget.isHost) return;
    if (_sharing) {
      try {
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(publishScreenCaptureVideo: false),
        );
        await engine.stopScreenCapture();
        if (mounted) setState(() => _sharing = false);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't stop screen sharing.")),
          );
        }
      }
      return;
    }
    try {
      await engine.setScreenCaptureScenario(
        ScreenScenarioType.screenScenarioDocument,
      );
      await engine.startScreenCapture(
        const ScreenCaptureParameters2(captureVideo: true, captureAudio: false),
      );
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishScreenCaptureVideo: true),
      );
      if (mounted) setState(() => _sharing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't start screen sharing. Try again — you'll be asked to pick what to share.",
            ),
          ),
        );
      }
    }
  }

  /// Closes a half-started share when the screen dies mid-flow (e.g. the
  /// consent dialog was dismissed right as the user left the call).
  Future<void> _stopShareIfActive() async {
    if (!_sharing) return;
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishScreenCaptureVideo: false),
      );
      await engine.stopScreenCapture();
    } catch (_) {}
  }

  void _toggleBoard() {
    setState(() {
      _boardOpen = !_boardOpen;
      if (!_boardOpen) {
        _activeStroke = null;
      }
    });
  }

  void _boardPanStart(Offset position) {
    if (!widget.isHost) return;
    _activeStroke = _BoardStroke(
      color: _boardErasing ? null : _boardColor,
      width: _boardErasing ? 28 : 4,
      points: [position],
    );
  }

  void _boardPanUpdate(Offset position) {
    final stroke = _activeStroke;
    if (stroke == null || !widget.isHost) return;
    setState(() => stroke.points.add(position));
  }

  void _boardPanEnd() {
    final stroke = _activeStroke;
    if (stroke == null || !widget.isHost) return;
    setState(() {
      // Finished strokes are stored normalized (0..1 fractions of the board
      // area) so they render identically on every screen size and can be
      // broadcast to students without coordinate conversion.
      final normalized = _BoardStroke(
        color: stroke.color,
        width: stroke.width,
        points: [
          for (final p in stroke.points)
            Offset(
              _boardSize.width > 0 ? p.dx / _boardSize.width : 0,
              _boardSize.height > 0 ? p.dy / _boardSize.height : 0,
            ),
        ],
        normalized: true,
      );
      _boardStrokes.add(normalized);
      _activeStroke = null;
      unawaited(_sendBoardStroke(normalized));
    });
  }

  /// Broadcasts a finished stroke (or the clear) to every participant.
  /// Fire-and-forget: a failed sync never blocks teaching; the next event
  /// still lands.
  Future<void> _sendBoardStroke(_BoardStroke stroke) async {
    if (_leaving) return;
    try {
      await SecureApiService().postLiveBoardEvent(
        widget.liveSessionId,
        'stroke',
        {
          'color': stroke.color?.toARGB32() ?? 0xFF000000,
          'width': stroke.width,
          'points': [
            for (final p in stroke.points) [p.dx, p.dy],
          ],
        },
      );
    } catch (_) {
      // Best-effort sync.
    }
  }

  void _clearBoard() {
    setState(() {
      _boardStrokes.clear();
      _activeStroke = null;
    });
    if (!widget.isHost) return;
    unawaited(_sendBoardClear());
  }

  /// Broadcasts a board wipe to every participant. Fire-and-forget.
  Future<void> _sendBoardClear() async {
    if (_leaving) return;
    try {
      await SecureApiService()
          .postLiveBoardEvent(widget.liveSessionId, 'clear', {});
    } catch (_) {
      // Best-effort sync.
    }
  }

  /// Applies whiteboard events newer than [_boardCursor]: remote strokes are
  /// added and clears wipe the board, on every participant's screen.
  Future<void> _pollBoard() async {
    if (_leaving) return;
    try {
      final result = await SecureApiService().getLiveBoardEvents(
        widget.liveSessionId,
        afterSeq: _boardCursor,
      );
      final items = (result['items'] as List?) ?? const [];
      if (items.isEmpty || _leaving) return;
      _safeSetState(() {
        for (final item in items) {
          final event = item as Map<String, dynamic>;
          if (event['type'] == 'clear') {
            _boardStrokes.clear();
            _activeStroke = null;
          } else if (event['type'] == 'stroke') {
            final payload = (event['payload'] as Map<String, dynamic>?) ?? {};
            final rawPoints = (payload['points'] as List?) ?? const [];
            final points = <Offset>[
              for (final pt in rawPoints)
                if (pt is List && pt.length >= 2)
                  Offset(
                    (pt[0] as num).toDouble().clamp(0, 1),
                    (pt[1] as num).toDouble().clamp(0, 1),
                  ),
            ];
            if (points.length < 2) continue;
            _boardStrokes.add(
              _BoardStroke(
                color: payload['color'] is int
                    ? Color(payload['color'] as int)
                    : Colors.white,
                width: (payload['width'] as num?)?.toDouble() ?? 4,
                points: points,
                normalized: true,
              ),
            );
          }
        }
        final nextSeq = result['nextSeq'] as int?;
        if (nextSeq != null) _boardCursor = nextSeq;
      });
    } catch (_) {
      // Transient network failure — the next poll retries; never surface.
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    // Synchronous: every async callback from here on is dead. This is what
    // prevents setState during the route-teardown window (the
    // "_dependents.isEmpty" red screen).
    _leaving = true;
    setState(() => _ending = true);
    _pollTimer?.cancel();
    _pollTimer = null;
    // Best-effort: stop the projection before leaving so the FGS ends too.
    unawaited(_stopShareIfActive());
    if (widget.isHost) {
      // Never trap the user on screen for a slow network: if the close call
      // can't land in time, pop anyway — the server-side session idle timeout
      // reaps the session it couldn't close.
      try {
        await SecureApiService()
            .endLiveClass(widget.liveSessionId)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Best-effort leave.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) _chatUnread = 0;
    });
    if (_chatOpen) _scrollChatToBottom();
  }

  /// Fetches only what's newer than the newest message we already have
  /// ([_chatCursor], epoch millis of that message's createdAt). The list is
  /// always kept current; when the panel is closed, new arrivals bump the
  /// unread counter shown as a badge on the chat button.
  Future<void> _pollChat() async {
    if (_leaving) return;
    try {
      final result = await SecureApiService().getLiveChatMessages(
        widget.liveSessionId,
        afterEpochMs: _chatCursor,
      );
      final items = (result['items'] as List?) ?? const [];
      if (items.isEmpty || _leaving) return;
      _safeSetState(() {
        for (final item in items) {
          _chatMessages.add(item as Map<String, dynamic>);
        }
        final last = items.last as Map<String, dynamic>;
        final createdAt = DateTime.tryParse(last['createdAt'] as String? ?? '');
        if (createdAt != null) _chatCursor = createdAt.millisecondsSinceEpoch;
        if (!_chatOpen) _chatUnread += items.length;
      });
      if (_chatOpen) _scrollChatToBottom();
    } catch (_) {
      // Transient network failure — the next poll retries; never surface.
    }
  }

  Future<void> _sendChat([String? imageData]) async {
    final text = _chatController.text.trim();
    if ((text.isEmpty && imageData == null) || _chatSending) return;
    setState(() => _chatSending = true);
    try {
      final sent = await SecureApiService().sendLiveChatMessage(
        widget.liveSessionId,
        text,
        imageData: imageData,
      );
      if (_leaving) return;
      _safeSetState(() {
        _chatMessages.add(sent);
        final createdAt = DateTime.tryParse(sent['createdAt'] as String? ?? '');
        if (createdAt != null) _chatCursor = createdAt.millisecondsSinceEpoch;
      });
      _chatController.clear();
      _scrollChatToBottom();
    } catch (_) {
      if (_leaving || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send the message. Check your connection."),
        ),
      );
    } finally {
      if (!_leaving) setState(() => _chatSending = false);
    }
  }

  /// Picks an image from the gallery, compresses it to a small JPEG, and
  /// sends it as an inline chat attachment (data URI). Errors are silent —
  /// the picker cancel is the common case, not a failure.
  Future<void> _pickChatImage() async {
    if (_chatSending) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 45,
      );
      if (picked == null || _leaving) return;
      final bytes = await picked.readAsBytes();
      final dataUri =
          'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (dataUri.length > 2_100_000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image is too large to share in chat.')),
        );
        return;
      }
      await _sendChat(dataUri);
    } catch (_) {
      // Picker/encoding failure — nothing to surface mid-class.
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _leaving = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _watermarkMoveTimer?.cancel();
    _watermarkRefreshTimer?.cancel();
    _chatController.dispose();
    _chatScroll.dispose();
    if (!widget.recordingAllowed) {
      FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    // Unregister screen capture callback
    try { const MethodChannel('com.nexus.edu/security').invokeMethod('unregisterScreenCaptureCallback'); } catch (_) {}
    unawaited(_hostView?.dispose());
    unawaited(_remoteView?.dispose());
    _hostView = null;
    _remoteView = null;
    _cachedRemoteUid = null;
    unawaited(_teardownEngine());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return PopScope(
      // System back, AppBar back and iOS swipe all funnel through _leave(),
      // so a host can never exit without the session-close call — previously
      // only the on-screen "End class" button did it, orphaning a live
      // session server-side. Once _ending is set the pop itself is allowed.
      canPop: _ending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: NexusScreen(
        title: widget.title,
        transparentAppBar: true,
        applyTabletMaxWidth: false,
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (engine == null || _error != null)
              Center(
                child: Text(
                  _error ?? 'Connecting…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            else if (widget.isHost)
              AgoraVideoView(
                controller: _hostView ??= VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else if (_remoteUid != null)
              AgoraVideoView(
                controller:
                    _remoteView != null && _cachedRemoteUid == _remoteUid
                    ? _remoteView!
                    : (_remoteView = VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(uid: _remoteUid!),
                        connection: RtcConnection(
                          channelId: widget.channelName,
                        ),
                      )),
              )
            else
              const Center(
                child: Text(
                  'Waiting for the teacher to start the video…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            // Tiled forensic watermark — covers video, low opacity, diagonal, cannot be cropped
            // Second-camera recording still captures personalized trace. C++ hashed in Rust/C++ for obfuscation.
            if (_forensicText.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: _TiledForensicWatermark(text: _forensicText),
                ),
              ),
            if (widget.isHost && _joined)
              const Positioned(top: 8, left: 16, child: _LiveChip()),
            if (!widget.recordingAllowed)
              const Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(child: _RecordingBlockedChip()),
              ),
            // Moving forensic pill — jumps corners every 7s, hard to crop
            Positioned(
              right: _watermarkCorner == 0 || _watermarkCorner == 2 ? 16 : null,
              left: _watermarkCorner == 1 || _watermarkCorner == 3 ? 16 : null,
              top: _watermarkCorner == 2 || _watermarkCorner == 3 ? 56 : null,
              bottom: _watermarkCorner == 0 || _watermarkCorner == 1 ? 104 : null,
              child: IgnorePointer(
                child: _ForensicWatermark(
                  text: _forensicText.isNotEmpty
                      ? _forensicText
                      : (SecureApiService().organizationName?.isNotEmpty == true
                          ? 'Nexus Edu · ${SecureApiService().organizationName}'
                          : 'Nexus Edu · ${SecureApiService().userName}'),
                ),
              ),
            ),
            if (_screenCaptureDetected)
              const Positioned(
                top: 44,
                left: 0,
                right: 0,
                child: Center(
                  child: _ScreenCaptureWarningChip(),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: FittedBox(
                // Shrinks the whole toolbar instead of overflowing 28+ px on
                // narrow screens (small Androids, zoomed display settings).
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isHost) ...[
                      _RoundIconButton(
                        icon: _micMuted ? Icons.mic_off : Icons.mic,
                        onPressed: _toggleMic,
                        tooltip: _micMuted ? 'Unmute' : 'Mute',
                      ),
                      const SizedBox(width: AppSpace.md),
                      _RoundIconButton(
                        icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                        onPressed: _toggleCamera,
                        tooltip: _cameraOff ? 'Camera on' : 'Camera off',
                      ),
                      const SizedBox(width: AppSpace.md),
                    ] else ...[
                      // Students publish their microphone (they can ask
                      // questions live); this lets them mute themselves.
                      _RoundIconButton(
                        icon: _micMuted ? Icons.mic_off : Icons.mic,
                        onPressed: _toggleMic,
                        tooltip: _micMuted ? 'Unmute' : 'Mute',
                      ),
                      const SizedBox(width: AppSpace.md),
                    ],
                    _RoundIconButton(
                      icon: _boardOpen ? Icons.draw : Icons.draw_outlined,
                      onPressed: _toggleBoard,
                      tooltip: _boardOpen ? 'Close whiteboard' : 'Whiteboard',
                      active: _boardOpen,
                    ),
                    const SizedBox(width: AppSpace.md),
                    if (widget.isHost) ...[
                      _RoundIconButton(
                        icon: _sharing
                            ? Icons.stop_screen_share
                            : Icons.screen_share,
                        onPressed: widget.recordingAllowed
                            ? _toggleScreenShare
                            : null,
                        tooltip: widget.recordingAllowed
                            ? (_sharing ? 'Stop sharing' : 'Share screen')
                            : 'Screen share is disabled when recording is off',
                        active: _sharing,
                      ),
                      const SizedBox(width: AppSpace.md),
                    ],
                    // Chat button with an unread badge so a teacher always
                    // notices a student message without keeping chat open.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _RoundIconButton(
                          icon:
                              _chatOpen ? Icons.chat : Icons.chat_bubble_outline,
                          onPressed: _toggleChat,
                          tooltip: _chatOpen ? 'Close chat' : 'Open chat',
                        ),
                        if (_chatUnread > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 18),
                              child: Text(
                                _chatUnread > 99 ? '99+' : '$_chatUnread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: AppSpace.md),
                    NexusButton(
                      label: widget.isHost ? 'End class' : 'Leave',
                      variant: NexusButtonVariant.danger,
                      icon: Icons.call_end,
                      isLoading: _ending,
                      onPressed: _ending ? null : _leave,
                    ),
                  ],
                ),
              ),
            ),
            if (_chatOpen)
              Positioned(
                left: 12,
                right: 12,
                bottom: 96,
                top: 64,
                child: _ChatPanel(
                  messages: _chatMessages,
                  myUserId: widget.userAccount,
                  controller: _chatController,
                  scrollController: _chatScroll,
                  sending: _chatSending,
                  onSend: _sendChat,
                  onPickImage: _pickChatImage,
                ),
              ),
            if (_boardOpen)
              Positioned.fill(
                child: _WhiteboardOverlay(
                  strokes: _boardStrokes,
                  activeStroke: _activeStroke,
                  selectedColor: _boardColor,
                  erasing: _boardErasing,
                  interactive: widget.isHost,
                  onBoardSize: (size) {
                    if (size != _boardSize) _boardSize = size;
                  },
                  onSelectColor: (color) => setState(() {
                    _boardColor = color;
                    _boardErasing = false;
                  }),
                  onToggleEraser: () =>
                      setState(() => _boardErasing = !_boardErasing),
                  onClear: _clearBoard,
                  onClose: _toggleBoard,
                  onPanStart: _boardPanStart,
                  onPanUpdate: _boardPanUpdate,
                  onPanEnd: _boardPanEnd,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.messages,
    required this.myUserId,
    required this.controller,
    required this.scrollController,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
  });

  final List<Map<String, dynamic>> messages;
  final String myUserId;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: AppSpace.xs),
                const Text(
                  'Live chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${messages.length} message${messages.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpace.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _ChatBubble(
                        message: message,
                        mine: message['userId'] == myUserId,
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, size: 20, color: Colors.white70),
                  tooltip: 'Share an image',
                  onPressed: sending ? null : onPickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.brPill,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                NexusButton(
                  label: 'Send',
                  icon: Icons.send,
                  isLoading: sending,
                  onPressed: sending ? null : onSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.mine});

  final Map<String, dynamic> message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final isTeacher = message['isTeacher'] == true;
    final name = message['name'] as String? ?? '';
    final text = message['message'] as String? ?? '';
    final imageData = message['imageData'] as String?;
    final sentAt = DateTime.tryParse(message['createdAt'] as String? ?? '');
    final time = sentAt == null
        ? ''
        : ' · ${sentAt.toLocal().hour.toString().padLeft(2, '0')}:${sentAt.toLocal().minute.toString().padLeft(2, '0')}';
    final accent = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: mine ? accent : Colors.white12,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(mine ? AppRadius.md : 2),
            bottomRight: Radius.circular(mine ? 2 : AppRadius.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTeacher ? '$name · Teacher' : name,
              style: TextStyle(
                color: mine
                    ? Colors.white70
                    : (isTeacher ? Colors.amberAccent : Colors.white54),
                fontSize: 11,
                fontWeight: isTeacher ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            if (imageData != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 260,
                    maxHeight: 260,
                  ),
                  child: Image.memory(
                    base64Decode(
                      imageData.contains(',')
                          ? imageData.split(',').last
                          : imageData,
                    ),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (text.isNotEmpty)
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            if (time.isNotEmpty)
              Text(
                time,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Highlight ring for toggles that are currently on (whiteboard, share).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final button = CircleAvatar(
      radius: 26,
      backgroundColor: onPressed == null
          ? Colors.white12
          : active
          ? Colors.white38
          : Colors.white24,
      child: IconButton(
        icon: Icon(
          icon,
          color: onPressed == null ? Colors.white38 : Colors.white,
        ),
        onPressed: onPressed,
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Persistent identity watermark ("Nexus Edu · `org` or `user`") in the corner
/// of every live class. IgnorePointer so it never blocks the controls; low
/// alpha so it never competes with the video.
class _WatermarkLabel extends StatelessWidget {
  const _WatermarkLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Forensic watermark — personalized, moving, hard to crop. Shows hash+name+org+time.
/// Moves corners every 7s, so cropping fails. Built via C++ `nx_watermark_hash` + Rust fallback.
class _ForensicWatermark extends StatelessWidget {
  const _ForensicWatermark({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white24, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.verified_user, size: 12, color: Colors.white70),
        ],
      ),
    );
  }
}

/// Tiled diagonal forensic watermark — fills video stage, 0.07 opacity, rotated -18°.
/// Even second-camera recording captures it. Tiles every 220px.
class _TiledForensicWatermark extends StatelessWidget {
  const _TiledForensicWatermark({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final tiles = <Widget>[];
      // Create a grid of rotated texts
      for (double y = -60; y < c.maxHeight + 60; y += 140) {
        for (double x = -120; x < c.maxWidth + 120; x += 260) {
          tiles.add(Positioned(
            left: x,
            top: y,
            child: Transform.rotate(
              angle: -0.32, // -18°
              child: Opacity(
                opacity: 0.07,
                child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ));
        }
      }
      return Stack(children: tiles);
    });
  }
}

class _ScreenCaptureWarningChip extends StatelessWidget {
  const _ScreenCaptureWarningChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
      decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: AppRadius.brPill),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text('Screen capture blocked — live class is protected', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: AppRadius.brPill,
      ),
      child: const Text(
        '● LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecordingBlockedChip extends StatelessWidget {
  const _RecordingBlockedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: AppRadius.brPill,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.screen_lock_portrait, size: 14, color: Colors.white70),
          SizedBox(width: 6),
          Text(
            'Recording off for this class',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// One drawn line on the whiteboard. An eraser stroke has a null color and is
/// painted with the board background instead. Finished strokes (and all
/// remote strokes) are stored with `normalized: true` — points are 0..1
/// fractions of the board area so they render identically on any screen size.
class _BoardStroke {
  _BoardStroke({
    required this.color,
    required this.width,
    required this.points,
    this.normalized = false,
  });

  final Color? color;
  final double width;
  final List<Offset> points;
  final bool normalized;
}

/// Full-screen teaching surface over the video: draw with the finger, pick
/// colors, erase, clear. The host draws; every participant views — strokes
/// sync over the backend and land on every screen at the same spot.
class _WhiteboardOverlay extends StatelessWidget {
  const _WhiteboardOverlay({
    required this.strokes,
    required this.activeStroke,
    required this.selectedColor,
    required this.erasing,
    required this.interactive,
    required this.onBoardSize,
    required this.onSelectColor,
    required this.onToggleEraser,
    required this.onClear,
    required this.onClose,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final List<_BoardStroke> strokes;
  final _BoardStroke? activeStroke;
  final Color selectedColor;
  final bool erasing;

  /// The host draws; students view. Hides the drawing controls when false.
  final bool interactive;
  final ValueChanged<Size> onBoardSize;
  final ValueChanged<Color> onSelectColor;
  final VoidCallback onToggleEraser;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final ValueChanged<Offset> onPanStart;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onPanEnd;

  static const List<Color> _palette = [
    Colors.white,
    Colors.amber,
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.redAccent,
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              child: Row(
                children: [
                  const Text(
                    'Whiteboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!interactive) ...[
                    const Spacer(),
                    Text(
                      '${strokes.length} stroke${strokes.length == 1 ? '' : 's'} synced',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  if (interactive) ...[
                    IconButton(
                      tooltip: erasing ? 'Draw' : 'Eraser',
                      onPressed: onToggleEraser,
                      color: erasing ? Colors.amber : Colors.white70,
                      icon: Icon(
                        erasing
                            ? Icons.gesture
                            : Icons.cleaning_services_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear board',
                      onPressed: onClear,
                      color: Colors.white70,
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Close whiteboard',
                    onPressed: onClose,
                    color: Colors.white70,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    // Report once per layout so strokes can be normalized to
                    // this board's dimensions before broadcasting.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onBoardSize(size);
                    });
                    return GestureDetector(
                      onPanStart: interactive
                          ? (details) => onPanStart(details.localPosition)
                          : null,
                      onPanUpdate: interactive
                          ? (details) => onPanUpdate(details.localPosition)
                          : null,
                      onPanEnd: interactive ? (_) => onPanEnd() : null,
                      child: CustomPaint(
                        painter: _BoardPainter(
                          strokes: strokes,
                          activeStroke: activeStroke,
                          background: Colors.black,
                        ),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (interactive)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in _palette)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.xs,
                        ),
                        child: GestureDetector(
                          onTap: () => onSelectColor(color),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: selectedColor == color && !erasing
                                    ? Colors.white
                                    : Colors.white24,
                                width:
                                    selectedColor == color && !erasing ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints finished strokes plus the stroke being drawn right now. Eraser
/// strokes (null color) paint over the board background, so they erase
/// whatever is underneath them in the same way a real eraser does.
/// Normalized strokes are scaled by the current board size first.
class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.strokes,
    required this.activeStroke,
    required this.background,
  });

  final List<_BoardStroke> strokes;
  final _BoardStroke? activeStroke;
  final Color background;

  static Offset _scale(Offset point, Size size, bool normalized) {
    if (!normalized) return point;
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...strokes, ?activeStroke];
    for (final stroke in all) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color ?? background
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final scaled =
          stroke.normalized ? _scale(stroke.points.first, size, true) : stroke.points.first;
      final path = Path()..moveTo(scaled.dx, scaled.dy);
      for (final point in stroke.points.skip(1)) {
        final p = stroke.normalized ? _scale(point, size, true) : point;
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => true;
}
