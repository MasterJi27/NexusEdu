# Nexus Edu v1.6.1+28 — Release Notes (Play Store)

**Build:** `1.6.1+28` `versionCode 28` `targetSdk 36` `minSdk 24` `compileSdk 37`
**AAB:** `build/app/outputs/bundle/release/app-release.aab` 188.8 MB signed `upload-keystore.jks`
**APK:** `build/app/outputs/flutter-apk/app-release.apk` 284.8 MB (universal, for testing)
**Backend:** `nexus-edu-backend.azurewebsites.net` `health 200 db:connected`

## What's New — Forensic Live Class + 1M Scale + Organization

### 🔒 Live Class — Secure, Scalable, Anti-Record
* **Forensic watermark** tiled diagonal `a7f3 · Aarav · Sunrise School · 11:42 AM` (hash 8 + name + org + IST) opacity 0.07 tiled 260px — second-camera recording still captures personal trace. Moving pill bottom-right → corners every 7s, hard to crop. Built via C++ `nx_watermark_hash` FNV-1a + Dart `sha256` fallback + Rust `sha2` (`rust-watermark/src/lib.rs`).
* **OS anti-record** `FLAG_SECURE` when `recordingAllowed==false` + `DETECT_SCREEN_CAPTURE` `AndroidManifest:29` + `SecurityChannel.kt:155` reflection `ScreenCaptureCallback` → `_ScreenCaptureWarningChip` + `logActivity SCREEN_CAPTURE_DETECTED`.
* **Internally record** — teacher `recordingAllowed=true` → Go recorder bot SFU → Blob `recordings/live_<id>.mp4`, student join shows `● LIVE` + watermark, `endLiveClass` auto stop.
* **BLU** `live_class_provider.dart:1` — `LiveClassWatermarkNotifier`/`RecordingPolicy`/`AntiRecord` Riverpod, testable.

### 🏫 Organization — Truly 1M Multi-Tenant
* Per-teacher `organizationName/orgLogoUrl/accentColor` → global theme `AppSettings` + `AppTheme.parseAccent` (navy fallback) + `OrgBrandMark` in 8 screens `dashboard:81` `parent:670` `teacher_home:92`.
* Backend `Organization` model `prisma/schema.prisma:11` + `Section.organizationId` `schema.prisma:292` + migration `20260821120000`, 12 indexes `schema.prisma:155` for 1M hot paths.

### ⚡ 1M Scale — Zero-Cost Student Free
* **Bicep** `infra/bicep/main.bicep:43` `param env='free'|'prod'` — `free` → App Plan `F1` + Postgres `B1ms` + no Redis/FrontDoor (₹0), `prod` → `P1v3` 3-30 autoscale `main.bicep:696` + `GP_D4s_v3` + `Premium P1` Redis `main.bicep:422` + `GZRS` `main.bicep:279` + `WAF Premium` — 5 private endpoints `main.bicep:211`.
* **Backend** pool `max:20` `lib/prisma.ts:8` + read replica `lib/prismaRead.ts`, `RedisStore` `middlewares/rateLimit.ts:32` + `tokenBucket.ts:77` Lua atomic, `Queue` `lib/queue.ts:105` `Worker` `workers/notificationWorker.ts:1`, `parsePagination 20` `routes/assignments.ts:12` `prisma.validate` clean.
* **Frontend** `cached_network_image` 6 hits `Image.network` 0, `PaginatedList` `core/utils/pagination.dart:5` wired `leaderboard:178`, `SharedPreferences` `_enforceCap` 800KB→400 `app_settings.dart:251`, `shrinkWrap` `ClampingScrollPhysics`.

### 🛡️ Security
* `AES-256-GCM` `aes_encryption_service.dart:44` `bytes.length==32` fail-closed, `NonceService` `maxSize 5000` + domain `nonce_service.dart:10`, `network_security_config.xml:14` pin-set `2027-01-01`, 5 private endpoints, `allowBackup=false` `AndroidManifest:34`.

### ✅ Verification
* `az bicep build` 0 errors (BCP334/081 warnings only), `npx tsc --noEmit` 0, `flutter build` 188.8/284.8 MB OK, `az webapp show` `Running` `curl /api/health` `200 db:connected` (fresh `dist/index.js:193` `/api/ready` after restart).

---
**Play Console Checklist:**
- [x] `versionCode 28` > live `15` → update accepted
- [x] `targetSdk 36` `minSdk 24` `isMinify+shrink` `proguard-rules.pro:20`
- [x] `aab` 188.8 MB signed `upload-keystore.jks` `android/key.properties:1`
- [x] Data safety: `RECORD_AUDIO`/`CAMERA`/`LOCATION`/`BLUETOOTH_SCAN` declared `AndroidManifest:3`
- [x] Screenshots `playstore_screenshots 1.6MB` + `google.png 392KB` ready
- Upload: `Play Console > Production > Create new release > Upload AAB > Release notes above > Review > Start rollout` (20%→100% over 2d)

**Previous:** `1.2.5+15` → `1.6.1+28` — organization + watermark + 1M hardening.
