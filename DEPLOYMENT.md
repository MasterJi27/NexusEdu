# Nexus Edu — Deployment Blueprint

Flutter app (package `com.nexus.edu`, minSdk 24, target latest). Backend: Azure-hosted Express API at `https://nexus-edu-backend.azurewebsites.net` (App Service `nexus-edu-backend` in RG `nexus-edu-prod`).

## Pre-flight (every release)

```powershell
flutter analyze          # must be: No issues found
flutter test             # must be: All tests passed
```

## 1. Signing (one-time per machine)

```powershell
keytool -genkey -v -keystore E:\Projects\nexus_edu\android\upload-keystore.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

Create `android/key.properties` (gitignored):

```
storePassword=<your-store-pass>
keyPassword=<your-key-pass>
keyAlias=upload
storeFile=E:/Projects/nexus_edu/android/upload-keystore.jks
```

`android/app/build.gradle.kts` picks this up automatically; without it, release builds fall back to debug signing (OK for testing, never for Play Store).

## 2. Build release artifacts

```powershell
# Release APK (direct install)
flutter build apk --release --dart-define=API_BASE_URL=https://nexus-edu-backend.azurewebsites.net

# Play Store bundle (Android App Bundle) — upload this to Google Play Console
flutter build appbundle --release --dart-define=API_BASE_URL=https://nexus-edu-backend.azurewebsites.net
```

Artifacts:
- `build\app\outputs\flutter-apk\app-release.apk`
- `build\app\outputs\bundle\release\app-release.aab`

`API_BASE_URL` is baked in at build time via `String.fromEnvironment` (`lib/core/services/secure_api_service.dart:16`). Omit the flag to use the Azure default.

## 3. Install on emulator / device

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-release.apk
& $adb -s emulator-5554 shell am start -n com.nexus.edu/.MainActivity
```

## 4. AI & RAG configuration

All AI runs on **free tiers only** — no paid provider anywhere.

| Setting | Default | Notes |
|---|---|---|
| `AI_MODEL` | `llama-3.1-8b-instant` | Lowest-latency free chat model (~100ms, 30 req/min, 6k TPM free) via the existing key |
| `RAG_ENABLED` | `true` | Turns knowledge retrieval on/off |
| `EMBEDDING_PROVIDER` | `openrouter` | `groq` (nomic-embed-text-v1_5 — only if the Groq account has embeddings access) or `openrouter` (free `nvidia/nemotron-3-embed-1b:free`). Any other value falls back to `groq`. |
| `OPENROUTER_API_KEY` | — | Required for the OpenRouter embedding provider (free key at openrouter.ai, `sk-or-v1-…`) |
| `EMBEDDING_MODEL` | provider default | Optional override |

RAG flow: teacher notes are chunked + embedded on create (`/api/teacher-notes`), the query is embedded at chat time, top-5 chunks by cosine similarity are injected into the system prompt of `/api/ai/chat` and `/api/ai/tutor-stream`. Indexing failures are silent and never block note creation. Discussions/replies are indexed the same way.

**One-time DB migration** (run after deploy, before enabling RAG):

```bash
psql "$DATABASE_URL" -f prisma/manual_sql/rag.sql   # creates pgvector extension + KnowledgeChunk table
```

## 4b. AI feature endpoints

| Endpoint | What it does | Free provider |
|---|---|---|
| `POST /api/ai/chat` | General chat, RAG-grounded, prompt-guard filtered | llama-3.1-8b-instant |
| `POST /api/ai/tutor-stream` | Streaming SSE tutor chat | llama-3.1-8b-instant |
| `POST /api/ai/agent` | Data agent: tool calling over the student's real profile, attendance, AI usage, assignments, notes (max 3 tool rounds) | llama-3.1-8b-instant |
| `POST /api/ai/solve-math` | Wolfram + AI explainer | Wolfram + llama |
| `POST /api/ai/generate-quiz` | Structured MCQ JSON (topic, subject, grade, count) | llama JSON mode |
| `POST /api/ai/grade-assignment` | Rubric JSON grade (score, strengths, weaknesses, grammar) | llama JSON mode |
| `POST /api/ai/transcribe` | Speech-to-text (multipart `audio` field) | whisper-large-v3-turbo |
| `POST /api/ai/speech` | Text-to-speech → mp3 | orpheus-v1-english |
| `GET /api/ai/parent-digest` | 7-day AI summary for parents (in-app, no SMTP needed) | llama |
| `GET /api/ai/usage` | Token/request usage report per user | — |

**One-time Groq console action**: accept the model terms for `canopylabs/orpheus-v1-english` (TTS) at console.groq.com/playground?model=canopylabs%2Forpheus-v1-english — free, otherwise TTS returns 400. Whisper and prompt-guard need no extra setup.

## 4c. Parent digest email — Composio (no SMTP needed)

The daily parent digest can be delivered through a **Gmail account connected to your Composio workspace** (`GMAIL_SEND_EMAIL` tool, v3 APIs, `@composio/core` SDK). Delivery order: Composio → SMTP → in-app only.

Setup (one time, ~2 minutes):

1. `COMPOSIO_API_KEY=ak_…` in `backend/.env` (from console.composio.dev).
2. `npm install` (adds `@composio/core`) then `npm run composio:connect` — prints a Google OAuth URL.
3. Open the URL, approve Gmail access. The script confirms with `Gmail already connected and ACTIVE`.
4. Verify: `npm run build && node -e "require('dotenv').config({path:__dirname+'/.env'});require('./dist/services/composioMailer.js').isGmailConnected().then(console.log)"` → `true`.

Notes: the app's own Gmail is used as sender; `DIGEST_FROM_EMAIL`/`SMTP_*` are ignored while Composio is active. The old `composio-core` package is retired (its v1 API returns 410) — the code uses `@composio/core` with `connectedAccounts.link` + `tools.execute`. Sending requires one ACTIVE Gmail connection; expired connections are ignored.

## 5. Security posture (already enforced)

- `usesCleartextTraffic` removed — HTTPS only.
- AI/backend keys live server-side; app only holds the user token in `FlutterSecureStorage`.
- `.env` and `key.properties` are gitignored.
- Network calls: all API traffic hits the Azure backend over TLS.

## 5. Release checklist

- [ ] `flutter analyze` + `flutter test` green
- [ ] Version bump in `pubspec.yaml` (`version: X.Y.Z+build`)
- [ ] Brand assets: navy (`#26377A`) splash + launcher icon already in `android/app/src/main/res`
- [ ] App label: "Nexus Edu" (manifest)
- [ ] Sign with `upload-keystore.jks` → upload `.aab` to Play Console
- [ ] `flutter pub upgrade` + re-run tests before shipping
- [ ] Emulator smoke test: onboarding → sign up/in → each tab → one tool call
