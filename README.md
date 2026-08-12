# NexusEdu: Advanced AI Learning Ecosystem

NexusEdu is an AI-powered education app for Indian students — CBSE, ICSE, JEE, NEET, NCERT solutions and 60+ AI features. The Flutter app talks to an Express + Prisma backend that proxies all AI calls (Groq), tracks every token, enforces daily AI quotas and rate limits.     https://play.google.com/store/apps/details?id=com.nexus.edu

## Architecture

```text
lib/
 ├── app/          (Router + AuthState — route guard & login flow)
 ├── core/
 │    ├── services/    (SecureApiService, AiService, OpenRouterService, ...)
 │    ├── repositories/
 │    ├── models/  (AppUser, StudyNote)
 │    ├── data/    (LearningCatalog, MonetizationCatalog)
 │    ├── theme/   (Dark theme, Google Fonts)
 │    └── utils/   (Result<T>)
 ├── features/     (60+ features, one folder each)
 └── shared/
      ├── constants/
      └── widgets/ (NexusButton, NexusCard, NexusTextField, LoadingOverlay, ErrorDisplay)

backend/            (Express + Prisma, deployed to Azure App Service)
 └── src/
      ├── routes/       (auth, ai, users, courses, ...)
      ├── controllers/  (auth business logic)
      ├── services/     (aiService — Groq/Wolfram proxy + token usage tracking)
      ├── middlewares/  (auth, role guard, rate limit, error handler)
      └── lib/          (prisma, env, logger)
```

## User flow (login & onboarding)

1. App opens → `AuthState` (loaded at startup) drives the GoRouter `redirect`.
2. Not signed in → `/login`; guest users can browse freely.
3. Signed in → first-time privacy policy → onboarding (class/board/subjects) → dashboard.
4. Logout revokes the device session server-side; router immediately guards all routes again.
5. Forgot password is a real flow: `POST /api/auth/forgot-password` issues a 30-minute token
   (dev mode shows the token in-app; production must deliver it via email), then
   `POST /api/auth/reset-password` swaps the password and revokes all sessions.

## AI, prompts & token tracking

- **No AI keys in the app.** Every AI call goes through `POST /api/ai/chat`,
  `/api/ai/tutor-stream` (SSE) or `/api/ai/solve-math` (Wolfram Alpha + Groq).
- **Centralized prompts & model config** in `backend/src/services/aiService.ts`
  (`systemPrompts`, `aiConfig` — model, temperature, daily quota). If a client omits a
  system prompt, a safe general tutor prompt is injected server-side.
- **Token accounting** (`AiUsageLog` table): every call records prompt/completion tokens,
  latency, feature and status. `GET /api/ai/usage` returns today/week/month totals,
  per-feature breakdown and recent failures — shown in the app's **Settings → AI usage & tokens**.
- **Daily AI quota** (business logic): `DAILY_AI_QUOTA_TOKENS` (default 200k) per user per day;
  exceeding it returns 429 with remaining quota info.
- **Rate limiting** (express-rate-limit): global 300/15min baseline, login 5/15min, AI
  per-user 60/15min keyed on the authenticated user id (IP fallback via `ipKeyGenerator`).

## Security & system design

- JWT + server-side device session binding; max 2 active devices per account.
- `requireRole(...)` middleware; zod body validation on every route.
- Security headers, request logging with timing, JSON body-size cap, central error handler
  + 404 handler, graceful shutdown, DB health check on `/api/health`.
- Password reset tokens stored hashed (SHA-256) with 30-min expiry; enumeration-safe responses.
- Google sign-in via server-side ID-token verification (`google-auth-library`).

## How to run

### App
```bash
flutter pub get
flutter run
```

### Backend
```bash
cd backend
npm install
npx prisma generate
npm run build     # compiles src/ -> dist/
npm run dev       # ts-node for development
```
Startup (`npm start` / `startup.js`) runs `prisma generate` + `prisma migrate deploy` so schema
changes apply automatically on Azure, with a real migration history under `prisma/migrations/`
instead of the `db push --accept-data-loss` this replaced.

### Environment variables (`backend/.env`, never commit)

| Variable | Required | Notes |
|---|---|---|
| `JWT_SECRET` | Yes | Server refuses to start without it. |
| `DATABASE_URL` | Yes | PostgreSQL connection string. |
| `GROQ_API_KEY` | For AI features | Server-side only — never shipped in the app. |
| `GROQ_MODEL` | No | Default `llama3-8b-8192`. |
| `DAILY_AI_QUOTA_TOKENS` | No | Default `200000` tokens/user/day. |
| `WOLFRAM_APP_ID` | For math solver | Used by `/api/ai/solve-math`. |
| `GOOGLE_SERVER_CLIENT_ID` | For Google sign-in | Must match the client's OAuth web client ID. |
| `ALLOWED_ORIGINS` | Recommended in prod | Comma-separated CORS allowlist. |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Optional | Azure Application Insights telemetry. |
| `APP_URL` | No | Used in reset-password dev links. |
| `PORT` | No | Defaults to 3000; Azure sets this automatically. |
| `NODE_ENV` | Recommended | Set to `production` on Azure. |
| `DEV_ALLOW_RESET_TOKEN_IN_RESPONSE` | Never in prod | If `true`, forgot-password echoes the raw reset token in the API response (dev convenience only). Default `false`. |

### Deploy
```bash
cd backend
npm run build
python deploy_azure.py   # zips dist/, prisma/, node_modules/ and deploys via az CLI
```
