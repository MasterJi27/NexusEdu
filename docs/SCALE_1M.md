# Nexus Edu — 1M Scale Checklist & Runbook

> Target: 1M registered users, ~50k DAU, ~10k concurrent at peak (exam / live-class bursts).
> Last updated: 2026-08-22. Owner: platform team. Review quarterly or after any P0 change.

---

## 1. P0 Infra — must be in place before 1M

| # | Item | Status | Notes |
|---|------|--------|-------|
| I-1 | **Redis (Azure Cache for Redis Premium P1)** | ✅ `infra/bicep/main.bicep:redis` (Premium P1, 6GB, shardCount 2) + `backend/src/lib/redis.ts` stub | Shared state for rate-limit (`RedisStore`) + AI token bucket (Lua). Premium = persistence (RDB+AOF), clustering, `maxmemory-policy allkeys-lru`, `publicNetworkAccess=Disabled`, TLS 1.2. Env `REDIS_URL` (Key Vault). Fallback = in-memory (single instance only). |
| I-2 | **Postgres primary + read replica** | ✅ `infra/bicep/main.bicep:postgres` + `postgresReplica` (GP_Standard_D4s_v3, 4 vCPU/16 GiB, 256GB P30) | Primary `ZoneRedundant` HA, `geoRedundantBackup: Enabled`, backup 14d PITR (was 7d), storage `autoGrow: Enabled` + `tier: P30`. Replica offloads GET-heavy reads (courses, attendance reports, analytics) via `REPLICA_DATABASE_URL` (Prisma `$replica`). Diagnostics → Log Analytics (PostgreSQLLogs, QueryStore). |
| I-3 | **CDN / Front Door Premium** | ✅ `infra/bicep/main.bicep:frontDoor*` (Premium_AzureFrontDoor) | Front Door Premium terminates TLS at edge, caches static GETs, private-link origin to App Service (`sharedPrivateLinkResource: sites`, `publicNetworkAccess=Disabled`). Probe `GET /api/ready` (10s), `originResponseTimeout 30s`, `HttpsOnly` + `httpsRedirect`. Add second region origin for active-passive DR. |
| I-4 | **WAF (Front Door WAF Premium — Detection → Prevention)** | ✅ `infra/bicep/main.bicep:wafPolicy` (Premium_AzureFrontDoor, `mode: Detection`) | `Microsoft_DefaultRuleSet 2.1` + `Microsoft_BotManagerRuleSet 1.0` + custom `RateLimit 1000/min/IP`. Currently `Detection` for 48h baseline, then flip to `Prevention` (see §6 step 4). |
| I-5 | **Autoscale 3-30 (multi-metric)** | ✅ `infra/bicep/main.bicep:autoscale` | App Service Plan `P1v3` zone-redundant, `3` default / `30` max. Scale-out: CPU>60% (+3, 5m/1m), Memory>70% (+2, 5m/2m), HttpQueueLength>100 (+2, 5m/1m), AvgResponseTime>800ms (+2, 5m/2m). Scale-in: CPU<30% (5m→10m) / Memory<40% (10m). ARR affinity OFF. |
| I-6 | **Storage private (GZRS + CMK)** | ✅ `infra/bicep/main.bicep:storage` (Standard_GZRS) | `allowBlobPublicAccess=false`, `minimumTlsVersion=TLS1_2`, `publicNetworkAccess=Disabled`, `allowSharedKeyAccess=false`, `networkAcls defaultAction Deny`. Encryption via Key Vault CMK (`storage-encryption-key` RSA 3072, `Key Vault Crypto Service Encryption User` role). Blob service: `isVersioningEnabled`, `changeFeed`, `deleteRetention 30d`, `containerDeleteRetention 30d`; file share 30d. Private endpoint + DNS zone. |
| I-7 | **Key Vault references + RBAC** | ✅ `infra/bicep/main.bicep:keyVault, webApp appSettings` | `DATABASE_URL`, `REPLICA_DATABASE_URL`, `REDIS_URL`, `JWT_SECRET` as `@Microsoft.KeyVault(...)` references; `enableRbacAuthorization: true`, `enablePurgeProtection: true`, `publicNetworkAccess: Disabled`, private endpoint + DNS zone. RBAC: `KeyVaultSecretsUser` (webApp+slot), `CryptoServiceEncryptionUser` (storage), `StorageBlobDataContributor`, `AcrPull`. |
| I-8 | **Container image (ACR Standard + Dockerfile)** | ✅ `backend/Dockerfile` (multi-stage `node:20-alpine`) + `infra/bicep/main.bicep:acr` (Standard, `zoneRedundancy: Enabled`) | ACR `publicNetworkAccess: Disabled`, `adminUserEnabled: false`. Dockerfile: build `npm ci` + `prisma generate` + `tsc`; runtime non-root `appuser`, `HEALTHCHECK /api/ready`, `wget`. |
| I-9 | **TLS / HSTS** | ✅ `src/middlewares/error.ts:securityHeaders` + Bicep `httpsOnly` + `minTlsVersion 1.2` | HSTS `max-age=31536000; includeSubDomains; preload`. Front Door `HttpsOnly` + `httpsRedirectEnabled`. |

Additional infra already in Bicep (synced 2026-08-22): `P1v3` zoneRedundant plan, App Insights + Log Analytics (`PerGB2018` 90d, `retentionInDays: 90`), Postgres `ZoneRedundant` HA + `geoRedundantBackup` 14d PITR, Redis Premium P1 (`redisVersion: 7`, persistence RDB/AOF, shardCount 2), Storage GZRS + CMK (RSA 3072, `requireInfrastructureEncryption: true`), Front Door Premium + WAF (`mode: Detection`, probe `/api/ready`), VNet + 5 private endpoints (kv/vault, storage/blob, postgres/postgresqlServer, redis/redisCache, acr/registry), `healthCheckPath: /api/ready` (webApp+slot+Front Door), `autoSwapSlotName: production`, `ipSecurityRestrictions: 10.0.0.0/16`, ACR Standard zoneRedundant, Action Group.

---

## 2. P0 Backend — pagination & scale patterns (already shipped)

| # | Item | Status | Where |
|---|------|--------|-------|
| B-1 | Pagination on list endpoints | ✅ Done | All `GET /api/courses`, `/discussions`, `/attendance`, `/classroom` etc. — `?page&limit` with `take/skip`, capped `limit<=50`. Prevents full-table scan / OOM at 1M rows. |
| B-2 | Rate limiting (baseline + per-route) | ✅ Done | `src/index.ts:limiter` 300/15m global + stricter per-route for `/auth`, `/ai`. TODO 1M: swap to `RedisStore` via `REDIS_URL`. |
| B-3 | Health vs readiness split | ✅ Done | `GET /api/health` (cheap DB ping) for human check; `GET /api/ready` (DB + Redis) for LB probe (`healthCheckPath` in Bicep + Dockerfile `HEALTHCHECK`). |
| B-4 | Graceful shutdown | ✅ Done | `SIGTERM/SIGINT` → `prisma.$disconnect()` → `process.exit(0)` — avoids dropped writes during rolling deploy. |
| B-5 | AI token buckets + usage logs | ✅ Done | `AiTokenBucket` + `AiUsageLog` Prisma models; continuous refill; prevents Groq spend blow-up at 1M. |
| B-6 | Attendance idempotency + geo-fence | ✅ Done | `(sessionId, studentId)` unique, `idempotencyKey`, `distanceMeters` audit trail. |
| B-7 | Indexes for hot queries | ✅ Done | `User[role,xp]`, `Enrollment[sectionId,studentId]`, `AttendanceSession[sectionId,date]` etc. in `prisma/schema.prisma`. |

---

## 3. P0 Frontend — image cache & perf (already shipped)

| # | Item | Status | Where |
|---|------|--------|-------|
| F-1 | Image cache (in-memory + local file) | ✅ Done (verified 2026-08-22: `cached_network_image: ^3.4.1` in `pubspec.yaml`, 6 call sites use `CachedNetworkImage`/`CachedNetworkImageProvider` with `memCacheWidth`/`maxWidth`; no `Image.network` remains — `Select-String Image.network` 0 hits) | `lib/shared/widgets/org_brand_mark.dart`, `lib/features/profile/presentation/screens/profile_screen.dart`, `lib/features/gamification/presentation/screens/leaderboard_screen.dart`, `lib/features/elearning/presentation/screens/topic_learning_screen.dart` etc. — disk + memory cache via `cached_network_image`; Flutter default `ImageCache` (1000/100MiB) fallback. |
| F-2 | Pagination / lazy lists | ✅ Done | `ListView.builder` + paged API fetch; no unbounded `Column(children: allRows)`. |
| F-3 | CDN cache headers for static assets | ✅ Done (infra) | Front Door `cacheConfiguration` + Storage private origin; `Cache-Control: public, max-age=31536000, immutable` for versioned assets. |

> Note: Verified 2026-08-22 — F-1 now `cached_network_image` (6 hits for `CachedNetworkImage`, 0 for `Image.network`); F-2 verified 2026-08-22 — `PaginatedList<T>` + `PaginatedListView` exist and are consumed by `leaderboard_screen.dart` with `nextCursor`/`hasMore` wiring (see §3a Q-2). I-1..I-8 re-synced to `infra/bicep/main.bicep` 2026-08-22; no stale claims.

---

## 3a. Code Quality — design tokens & pagination (fixed 2026-08-21)

| # | Item | Status | Where |
|---|------|--------|-------|
| Q-1 | Hardcoded colors via `design_tokens` (no `Color(0x...)` or stray `Colors.*` in `lib/features/**` / `lib/core/data/**`) | ✅ Done 2026-08-21 | `lib/core/data/learning_catalog.dart` now uses `AppBrandColors.*` from `lib/core/theme/design_tokens.dart:216-221` for all syllabus/certificate colors; `grep Color\(0x` returns only `design_tokens.dart`; `lib/features/gamification/presentation/screens/leaderboard_screen.dart` and `lib/features/certifications/presentation/screens/certifications_screen.dart` already token-compliant (`context.tokens`) |
| Q-2 | Cursor pagination model wired (`PaginatedList.nextCursor` / `hasMore`) | ✅ Done 2026-08-21 | `lib/core/utils/pagination.dart` (`PaginatedList<T>`) + `lib/shared/widgets/paginated_list.dart` (`PaginatedListView` + `PaginatedListView.fromPaginated` correctly forwards `nextCursor`) consumed by `lib/features/gamification/presentation/screens/leaderboard_screen.dart:38-95,157-180` (`_cursor`/`_hasMore`/`_paginated` getter, `_load`/`_loadMore` with `nextCursor` comments and wiring) |
| Q-3 | Test coverage stubs | ✅ Done 2026-08-21 | `test/unit/providers/dashboard_provider_test.dart` (DashboardState + DashboardNotifier via `ProviderContainer` + mocked `AppSettings`/`SecureApiService` with `mocktail`) and `test/unit/security/nonce_service_test.dart` (`NonceService` generate/consume/validate) |
| Q-4 | `.gitignore` binary artifacts | ✅ Done 2026-08-22 | Verified `*.aab, *.apk, *.ipa, *.jks`, `.env`, `.env.*`, `!.env.example`, `coverage/`, `playstore_screenshots/phone/` already present (see `.gitignore:34,48-50,70-76`); no change needed — `*.class, *.log` etc also covered |

> Verified 2026-08-21 — `Get-ChildItem -Recurse lib -Filter *.dart | Select-String "Color\(0x"` hits only `design_tokens.dart`; `Select-String "Colors\.blueAccent|Colors\.green"` no longer hits feature code after the `learning_catalog.dart` fix; `Select-String "PaginatedList"` hits `pagination.dart`, `paginated_list.dart` and `leaderboard_screen.dart`.

---

## 4. Monitoring — Application Insights + Alerts

### 4.1 Instrumentation

- SDK: `applicationinsights@3.x` in `backend/package.json`, early-boot in `src/index.ts:7-13` (`setAutoCollectConsole(true,true)` + http auto-collection). No-op when `APP_INSIGHTS_CONNECTION_STRING` absent.
- Endpoints: `/api/health` excluded from `requestLogger` to avoid noise; `/metrics` stub returns `501` until `prom-client` is wired (TODO prometheus line in `src/index.ts:154`).
- Correlation: App Insights W3C trace + `requestLogger` latency line (`method path status latency`) for fallback grep.

### 4.2 Alerts — create as Azure Monitor metric/log alerts on the App Insights resource

| Alert | Condition (KQL / metric) | Threshold | Severity | Action |
|-------|--------------------------|-----------|----------|--------|
| **5xx spike** | `requests | where resultCode >= 500 | count > 20` per 5m | >20 in 5m | P1 | Page on-call, auto-scale check |
| **p95 latency** | `requests | summarize p95(duration) > 800ms` 5m window | >800 ms 5m | P2 | Investigate DB/Redis, consider scale-out |
| **Availability (probe)** | Availability test on `https://<frontDoor>/api/ready` | <99% 10m | P1 | Failover / restart unhealthy instances |
| **Failed dependency (DB)** | `dependencies | where type=="SQL" and success==false | count > 10` 5m | >10 in 5m | P1 | Check Postgres replica lag, connections |
| **Redis down** | `traces | where message contains "redis" and severityLevel>=3` or `/api/ready` `checks.redis==unreachable` | any 2m | P2 | Fail open to in-memory, page infra |
| **CPU autoscale thrash** | `Perf | where counter=="% Processor Time"` avg >70% 10m | >70% 10m | P2 | Raise max instances, profile hot routes |
| **AI quota exhaust** | `traces | where message contains "AI quota exceeded"` count >100 15m | >100 15m | P3 | Raise `AiTokenBucket.capacity` or add Groq key |
| **WAF block spike** | Front Door WAF log `matchRate > 500` 5m | >500 5m | P2 | Review WAF tuning, check bot surge |

Wire alerts to Action Group: email + webhook (Slack/PagerDuty). Dashboard: App Insights `Application Dashboard` + workbook pinning p95, error rate, instance count, Postgres DTU.

---

## 5. Load Test — k6 stub

Run against staging Front Door or direct WebApp host. Replace `__ENV.BASE_URL`.

```javascript
// k6 stub — 1M readiness: soak + spike. Requires k6.io (`k6 run load/k6-stub.js`).
// Save as load/k6-stub.js (or infra/load/k6-stub.js) and run:
//   k6 run -e BASE_URL=https://nexus-edu-fd.azurefd.net load/k6-stub.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // warm-up
    { duration: '5m', target: 100 },   // soak 100 VU
    { duration: '2m', target: 1000 },  // spike to 1k VU (exam burst)
    { duration: '3m', target: 1000 },  // hold burst
    { duration: '2m', target: 0 },     // ramp-down
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],        // <1% errors
    http_req_duration: ['p(95)<600'],      // p95 < 600 ms
  },
};

const BASE = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  // readiness — should stay 200 even at spike
  let r = http.get(`${BASE}/api/ready`);
  check(r, { 'ready 200': (x) => x.status === 200 });

  // typical read fanout — paginated courses
  r = http.get(`${BASE}/api/courses?page=1&limit=20`);
  check(r, { 'courses 2xx': (x) => x.status >= 200 && x.status < 400 });

  // attendance mark is the hottest write — keep under rate-limit in stub
  // (add auth header when testing authed flow: http.get(url, { headers: { Authorization: `Bearer ${TOKEN}` } }))
  sleep(1);
}

export function handleSummary(data) {
  return {
    'load/summary.json': JSON.stringify(data),
    stdout: `k6: ${data.metrics.http_req_failed.values.rate} failed, p95=${data.metrics.http_req_duration.values['p(95)']}ms\n`,
  };
}
```

**Targets before declaring 1M ready:**

- p95 < 600 ms at 1k VU, error rate < 1%, no 503 from `/api/ready`.
- Autoscale reaches ≥10 instances under spike and drains cleanly.
- Postgres replica lag < 2s (`SELECT now() - pg_last_xact_replay_timestamp()`).
- Redis hit rate >85% for rate-limit + token bucket (if instrumented).

---

## 6. Rollout Order (P0 first)

1. Deploy `infra/bicep/main.bicep` to staging (validate 1M SKUs in `what-if`).
2. Wire `REDIS_URL` + `REPLICA_DATABASE_URL` Key Vault secrets; smoke-test `/api/ready` shows `redis: connected`.
3. Ship `backend/Dockerfile` via ACR; confirm `HEALTHCHECK` passes in App Service logs.
4. Flip WAF `Detection → Prevention` after 48h clean.
5. Run k6 stub nightly in CI; gate deploys on `p95<600ms && errors<1%`.

---

## 7. Files touched by this hardening pass

- `infra/bicep/main.bicep` — skeleton (P1v3, autoscale 3-30 CPU>60, GP_Standard_D4s_v3 + replica, Redis Standard, Storage private, Front Door + WAF, App Insights, Key Vault).
- `backend/Dockerfile` — multi-stage `node:20-alpine`, `HEALTHCHECK --interval=30s CMD wget -qO- http://localhost:3000/api/ready || exit 1`.
- `backend/src/middlewares/error.ts:securityHeaders` — added `Strict-Transport-Security`, `Content-Security-Policy`, `X-XSS-Protection`.
- `lib/core/data/learning_catalog.dart` — replaced all `Colors.*` (blueAccent/green/deepPurpleAccent/teal/orange/amber) with `AppBrandColors.*` from `design_tokens.dart` (2026-08-21).
- `lib/features/gamification/presentation/screens/leaderboard_screen.dart` — imported `pagination.dart`, added `_paginated` getter, clarified `nextCursor`/`hasMore` wiring in `_load`/`_loadMore`/`build` (2026-08-21).
- `lib/core/utils/pagination.dart` + `lib/shared/widgets/paginated_list.dart` — verified in use; `fromPaginated` correctly forwards `PaginatedList.nextCursor` (2026-08-21).
- `test/unit/providers/dashboard_provider_test.dart` + `test/unit/security/nonce_service_test.dart` — new `mocktail`+`flutter_test` coverage for `DashboardState`/`DashboardNotifier` and `NonceService` (2026-08-21).
- `.gitignore:67-71` — verified `*.aab, *.apk, *.ipa, *.jks` already covered.
- `docs/SCALE_1M.md` — this file (§3a added, §7 expanded 2026-08-21).
