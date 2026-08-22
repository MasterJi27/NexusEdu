# Nexus Edu

AI-powered education platform — Flutter app + Express + Prisma (Postgres) + Azure.

## Quick start

```bash
# backend
cd backend
cp .env.example .env  # fill from Key Vault — never commit .env
npm ci
npx prisma migrate dev
npm run dev            # http://localhost:3000/api/health

# app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Security — secrets

> **Never commit `.env`.** All API keys live server-side (backend) or in Azure Key Vault. The Flutter app has no bundled keys.

- `.env` and `backend/.env` are **git-ignored** (`.gitignore:48-52`, `backend/.gitignore:2-3`). Templates are `.env.example` / `backend/.env.example`.
- Local dev: `cp backend/.env.example backend/.env` and populate from Key Vault:

  ```bash
  az keyvault secret show --vault-name nexus-edu-kv --name GroqApiKey --query value -o tsv
  ```

- Production/staging: secrets are injected via **Key Vault references** (`@Microsoft.KeyVault(...)`) in `infra/bicep/main.bicep` — no plain-text app settings.
- **Gitleaks**: scan before push:

  ```bash
  gitleaks detect --source . --config .gitleaks.toml --verbose
  # CI runs: gitleaks detect --no-git --redact
  ```

- If a secret was ever committed: **rotate immediately** — see [`docs/SECRETS_ROTATION.md`](docs/SECRETS_ROTATION.md) (covers `GEMINI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`, `COMPOSIO_API_KEY`, `AZURE_*`, `AGORA_APP_CERTIFICATE`, `JWT_SECRET`, `DATABASE_URL`, etc., with Key Vault migration steps and `git filter-repo` purge).

- Enable GitHub **push protection** (Settings → Code security → Secret scanning) + pre-commit hook:

  ```bash
  pre-commit install  # runs gitleaks on commit
  ```

## Queue & Workers (Redis + BullMQ)

- `backend/src/lib/redis.ts` — single `getRedis()` singleton (`maxRetriesPerRequest: null`, `enableReadyCheck: false`, TLS for `rediss://`). Lazy when `REDIS_URL` unset.
- `backend/src/lib/queue.ts` — `getNotificationQueue()` creates `Queue('notifications', { connection: await getRedis(), ... })`. Falls back to direct DB `createMany` when Redis absent.
- `backend/src/workers/notificationWorker.ts` — `startWorkers()` reuses the **same** Redis connection (`const conn = await getRedis(); new Worker('notifications', ..., { connection: conn })`). Started in `backend/src/index.ts` inside `app.listen` alongside `startWorkers()` from `queue.ts`.
- Health: `GET /api/ready` checks `redis.ping()` when `REDIS_URL` is set.

## Docs

- [SCALE_1M.md](docs/SCALE_1M.md) — 1M scale checklist
- [SYSTEM_DESIGN_LIVE_CLASS.md](docs/SYSTEM_DESIGN_LIVE_CLASS.md) — live-class design
- [SECRETS_ROTATION.md](docs/SECRETS_ROTATION.md) — rotation & Key Vault runbook
