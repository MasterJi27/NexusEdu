# Nexus Edu — Live Class System Design (Masterpiece)

> Languages: Dart/Flutter (UI), Kotlin (Android), C++ (NDK crypto/watermark), Rust (integrity), Go (signaling) — polyglot by domain.

## 1. Goals
- **Secure**: no OS screen-record, forensic trace for second-camera, E2E `FLAG_SECURE` + `DETECT_SCREEN_CAPTURE`.
- **Scalable**: 1M concurrent viewers, Agora SFU + Go signaling + Redis presence, paginated chat/board.
- **Productive**: BLU clean, offline queue, instant join <1.2s.

## 2. Live Class BLU (Business Logic Units)

```
Presentation: LiveClassScreen (Flutter)
    ↓
Providers (Riverpod):
  - LiveClassSessionProvider (join/leave, token refresh)
  - LiveClassChatProvider (poll, send, unread badge)
  - LiveClassBoardProvider (strokes, clear, cursor)
  - LiveClassWatermarkProvider (forensic string, position, interval)
  - LiveClassRecordingPolicyProvider (FLAG_SECURE, internal record flag)
  - LiveClassAntiRecordProvider (screen capture callback, second-camera deterrence)
Domain: LiveSession, ChatMessage, BoardStroke, WatermarkPolicy
Data: Agora RtcEngine (video), SecureApiService (chat/board REST), WatermarkService (C++/Rust)
```

Each BLU is pure Dart + single responsibility, testable via `ProviderContainer`.

## 3. Watermark — Forensic, Moving, Student-bound

**What student sees after Join:**
- Dark video stage + `PILE LIVE` chip top-left
- Center tile: semi-transparent diagonal tiled watermark grid: `userId(8) | name | org | time IST` e.g. `a7f3 … Aarav · Sunrise School · 11:42 AM` rotated -18° opacity 0.07 tiled every 220px.
- Corner `_ForensicWatermark` (old `_WatermarkLabel` upgraded): bottom-right pill moves every 7s to 4 corners (prevents cropping), shows same string + `● LIVE` pulse.

**Why second camera fails:**
- Every frame contains personalized watermark at multiple tilings + corner moving label + invisible LSB steganography via C++ (`nx_watermark_hash`) — teacher can search leaked video by hash.
- Watermark string includes 8-char hash of `userId + liveSessionId` via Rust `sha256` (WASM) — not spoofable without token.

## 4. Anti-Record

- **First layer:** `FlutterWindowManagerPlus.FLAG_SECURE` when `recordingAllowed==false` (already). Blocks `MediaProjection` + screenshots OS-level. `AndroidManifest: DETECT_SCREEN_CAPTURE` + `setScreenCaptureCallback` (Android 14) shows `SnackBar "Screen capture detected — this class is protected"` and reports to backend.
- **Second layer:** Tiled watermark + moving corner → cropping still leaves trace.
- **Third layer (Go signaling):** Go service `live-signaling` (WS) broadcasts `recording:internal` flag. When teacher `recordingAllowed==true`, server records SFU side (compliant). Client never records locally when false — `publishScreenCaptureVideo:false`.

## 5. Internally Record Ho Raha Hai — Flow

```
Teacher Start → POST /classroom/sections/:id/live/start {recordingAllowed:true/false}
Server → creates LiveSession {channelName: live_<uuid>, recordingAllowed} + Agora token (role publisher)
       → if true, Go recorder joins as hidden bot, SFU record to Azure Blob `recordings/live_<id>.mp4`
Student Join → POST /classroom/live/:id/token (audience token) + GET watermark hash via SecureChannel
       → Flutter shows tiled watermark + starts anti-capture listener
Teacher End → POST /classroom/live/:id/end → server closes session, Go recorder stops, blob finalized, notification fanout via BullMQ
```

Even if student second-camera records, leaked clip still carries their ID.

## 6. Polyglot

- **C++ (`cpp/watermark.cpp`):** `nx_watermark_hash(userId, sessionId, ts)` → 8 hex, `nx_watermark_bitmap()` for LSB embed. Fast, obfuscated.
- **Rust (`rust-watermark/src/lib.rs`):** `fn forensic_hash(...) -> String` via `sha2`, compiled to `librust_watermark.so` via `cargo-ndk` (future).
- **Go (`services/live-signaling/main.go`):** WebSocket hub for chat/board presence, 10k conns per pod, Redis pubsub.
- **Dart:** BLU orchestration, UI.

## 7. Security

- `WsHeartbeatService` 25s ping/nonce + `AppIntegrityService` .text hash + `AntiDebugService` tracerPid/Frida.
- `network_security_config` pin `nexus-edu-backend.azurewebsites.net`.

