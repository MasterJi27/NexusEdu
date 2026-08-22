import './lib/loadEnv';
import { env } from './lib/env';

// Application Insights (Azure monitoring). Must be started before express so
// the http auto-instrumentation wraps every request. No-op when the
// connection string is absent (local dev).
if (env.APP_INSIGHTS_CONNECTION_STRING) {
  const appInsights = require('applicationinsights');
  appInsights
    .setup(env.APP_INSIGHTS_CONNECTION_STRING)
    .setAutoCollectConsole(true, true)
    .start();
}

import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import coursesRoutes from './routes/courses';
import assignmentsRoutes from './routes/assignments';
import aiRoutes from './routes/ai';
import aiContentRoutes from './routes/aiContent';
import aiDocsRoutes from './routes/aiDocs';
import usersRoutes from './routes/users';
import discussionsRoutes from './routes/discussions';
import feedbackRoutes from './routes/feedback';
import teacherNotesRoutes from './routes/teacherNotes';
import notesRoutes from './routes/notes';
import syncRoutes from './routes/sync';
import parentRoutes from './routes/parent';
import attendanceRoutes from './routes/attendance';
import classroomRoutes from './routes/classroom';
import liveClassRoutes from './routes/liveClass';
import adminRoutes from './routes/admin';
import azureAiRoutes from './routes/azureAi';
import errorsRoutes from './routes/errors';
import { resolveCorsOrigin } from './lib/cors';
import { authenticate } from './middlewares/auth';
import { requestLogger, securityHeaders, notFound, errorHandler } from './middlewares/error';
import rateLimit from 'express-rate-limit';
import { ipKey, getRateLimitStore } from './middlewares/rateLimit.js';
import prisma from './lib/prisma';
import { getRedis } from './lib/redis.js';
import { startDigestEmailWorker } from './services/digestMailer';
import { ensureRagSchema } from './services/ragService';
import { startWorkers } from './lib/queue.js';
import { startWorkers as startNotificationWorkers } from './workers/notificationWorker.js';
import { startRagWorker } from './workers/ragWorker.js';

const app = express();
const port = process.env.PORT || 3000;

app.disable('x-powered-by');
app.set('trust proxy', 2);

// ---- prom-client metrics (1M) ------------------------------------------------
// Try to load prom-client; if present, collect default metrics and expose /metrics.
// Falls back to 501 only if the dep is truly missing (package.json now includes it).
let metricsEnabled = false;
let promRegister: any = null;
let httpDurationHistogram: any = null;
let httpRequestsTotal: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const promClient = require('prom-client');
  promRegister = new promClient.Registry();
  promClient.collectDefaultMetrics({ register: promRegister, prefix: 'nexus_' });
  httpDurationHistogram = new promClient.Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.3, 0.5, 1, 2.5, 5],
    registers: [promRegister],
  });
  httpRequestsTotal = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status_code'],
    registers: [promRegister],
  });
  metricsEnabled = true;
} catch {
  metricsEnabled = false;
}

app.use(cors({ origin: resolveCorsOrigin(env.ALLOWED_ORIGINS, env.ALLOW_ALL_ORIGINS_DEV) }));

// Helmet-equivalent security headers are set via securityHeaders (see middlewares/error.ts)
// Optionally apply `helmet` library if installed for extra coverage — no-op if not present.
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const helmet = require('helmet');
  app.use(
    helmet({
      contentSecurityPolicy: false, // we set our own strict CSP in securityHeaders
      crossOriginEmbedderPolicy: false, // handled manually
    }),
  );
} catch {}

app.use(securityHeaders);
app.use(requestLogger);

// Metrics instrumentation — observe every request (after logger so we have timing)
if (metricsEnabled && httpDurationHistogram && httpRequestsTotal) {
  app.use((req, res, next) => {
    const end = httpDurationHistogram.startTimer();
    res.on('finish', () => {
      const route = (req.route && req.route.path) ? `${req.baseUrl}${req.route.path}` : req.path;
      const labels = { method: req.method, route, status_code: String(res.statusCode) };
      try {
        end(labels);
        httpRequestsTotal.inc(labels);
      } catch {}
    });
    next();
  });
}

// express.json with per-route limits (1M: prevent 1MB JSON bomb on auth, allow larger on uploads/AI)
const jsonLimits: Array<{ prefix: string; limit: string }> = [
  { prefix: '/api/ai', limit: '2mb' },
  { prefix: '/api/assignments', limit: '5mb' },
  { prefix: '/api/notes', limit: '5mb' },
  { prefix: '/api/teacher-notes', limit: '5mb' },
  { prefix: '/api/courses', limit: '500kb' },
  { prefix: '/api/auth', limit: '50kb' },
  { prefix: '/api/admin', limit: '1mb' },
];
app.use((req, res, next) => {
  let limit = '100kb'; // default strict — global 1mb was too permissive for 1M abuse
  for (const { prefix, limit: l } of jsonLimits) {
    if (req.path.startsWith(prefix) || req.originalUrl.startsWith(prefix)) {
      limit = l;
      break;
    }
  }
  // Multer routes (multipart) will be skipped by express.json anyway (non-json content-type)
  return express.json({ limit })(req, res, next);
});

/**
 * Global baseline limiter (generous — per-route limiters are the real
 * controls for auth and AI). Keeps a single misbehaving client from
 * saturating the box while never getting in the way of real usage.
 */
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  message: { status: 'error', message: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
  store: getRateLimitStore('rl:global:') as any,
  keyGenerator: ipKey,
});
app.use(limiter);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/courses', coursesRoutes);
app.use('/api/assignments', assignmentsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/ai', aiContentRoutes);
app.use('/api/ai', aiDocsRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/discussions', authenticate, discussionsRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api/teacher-notes', teacherNotesRoutes);
app.use('/api/notes', notesRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/parent', parentRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/classroom', classroomRoutes);
app.use('/api/classroom', liveClassRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/azure-ai', azureAiRoutes);
app.use('/api/errors', errorsRoutes);

// Health + readiness: verifies the DB is reachable so load balancers can
// take the instance out of rotation when it isn't.
app.get('/api/health', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({
      status: 'ok',
      message: 'Nexus Edu Backend is running',
      db: 'connected',
      uptime: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    });
  } catch {
    res.status(503).json({ status: 'degraded', message: 'Database unreachable' });
  }
});

// Liveness vs readiness split for 1M / K8s:
// - /api/health = liveness (process up, no dependency checks beyond cheap DB ping above for backwards compat)
// - /api/ready  = readiness (DB + Redis if configured must be reachable before receiving traffic)
app.get('/api/ready', async (_req, res) => {
  const checks: Record<string, string> = {};
  let ready = true;

  try {
    await prisma.$queryRaw`SELECT 1`;
    checks.db = 'connected';
  } catch {
    checks.db = 'unreachable';
    ready = false;
  }

  if (process.env.REDIS_URL) {
    try {
      const { getRedis } = await import('./lib/redis.js');
      const redis = await getRedis();
      if (redis) {
        // ioredis .ping() if connected, else treat as not ready only if explicit failure
        if (typeof redis.ping === 'function') {
          await redis.ping();
        }
        checks.redis = 'connected';
      } else {
        // REDIS_URL set but ioredis not installed / not connected yet — stub mode
        checks.redis = 'not_configured_stub';
      }
    } catch {
      checks.redis = 'unreachable';
      ready = false;
    }
  } else {
    checks.redis = 'not_configured';
  }

  if (ready) {
    res.status(200).json({ status: 'ready', checks, uptime: Math.round(process.uptime()), timestamp: new Date().toISOString() });
  } else {
    res.status(503).json({ status: 'not_ready', checks, timestamp: new Date().toISOString() });
  }
});

// Prometheus metrics — wired via prom-client (1M). Auth via x-metrics-token or internal 10.* IP.
app.get('/metrics', (req: any, res: any, next: any) => { const token = req.headers['x-metrics-token']; const ip = req.ip || ''; if (token === process.env.METRICS_TOKEN || ip.startsWith('10.')) return next(); res.sendStatus(403); }, async (_req, res) => {
  if (!metricsEnabled || !promRegister) {
    res.status(501).json({ error: 'Metrics not implemented', todo: 'Install prom-client: npm i prom-client' });
    return;
  }
  try {
    res.setHeader('Content-Type', promRegister.contentType);
    const metrics = await promRegister.metrics();
    res.status(200).send(metrics);
  } catch (e: any) {
    res.status(500).json({ error: 'Metrics collection failed', detail: e?.message });
  }
});

app.use(notFound);
app.use(errorHandler);

// P0: eager Redis connect before serving traffic (lazyConnect:false + ping in lib/redis.ts)
// @ts-ignore top-level await required for eager Redis - valid in ESM Node16
await getRedis().catch(()=>{});

const server = app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
  startDigestEmailWorker();
  void startWorkers(); // P0: lib/queue Worker (notifications + rag-index) using Redis instance
  void startNotificationWorkers(); // P0: workers/notificationWorker using getRedis()
  void startRagWorker(); // P0: workers/ragWorker
  // pgvector + KnowledgeChunk can't be created by `prisma migrate deploy`, so
  // they are ensured here rather than left to a manual psql step nobody
  // remembers on a fresh database. Idempotent, and never blocks serving traffic.
  void ensureRagSchema();
});
// Export for startup.js drain handling
(global as any).__nexusServer = server;

const shutdown = async (signal: string) => {
  console.log(`Received ${signal}, shutting down gracefully...`);
  // Stop accepting new connections, wait for in-flight to finish (up to 25s)
  server.close(async () => {
    console.log('HTTP server closed');
    await prisma.$disconnect();
    try {
      const { disconnectRedis } = await import('./lib/redis.js');
      await disconnectRedis();
    } catch {}
    process.exit(0);
  });
  // Force exit if drain hangs
  setTimeout(() => {
    console.log('Graceful shutdown timeout — forcing exit');
    process.exit(1);
  }, 25000).unref();
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

export { app, server };
