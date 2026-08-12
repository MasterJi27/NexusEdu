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
import usersRoutes from './routes/users';
import discussionsRoutes from './routes/discussions';
import feedbackRoutes from './routes/feedback';
import teacherNotesRoutes from './routes/teacherNotes';
import notesRoutes from './routes/notes';
import syncRoutes from './routes/sync';
import parentRoutes from './routes/parent';
import attendanceRoutes from './routes/attendance';
import classroomRoutes from './routes/classroom';
import azureAiRoutes from './routes/azureAi';
import errorsRoutes from './routes/errors';
import { resolveCorsOrigin } from './lib/cors';
import { authenticate } from './middlewares/auth';
import { requestLogger, securityHeaders, notFound, errorHandler } from './middlewares/error';
import rateLimit from 'express-rate-limit';
import prisma from './lib/prisma';
import { startDigestEmailWorker } from './services/digestMailer';
import { ensureRagSchema } from './services/ragService';

const app = express();
const port = process.env.PORT || 3000;

app.disable('x-powered-by');
app.set('trust proxy', 1);

app.use(cors({ origin: resolveCorsOrigin(env.ALLOWED_ORIGINS, env.ALLOW_ALL_ORIGINS_DEV) }));

app.use(securityHeaders);
app.use(requestLogger);
app.use(express.json({ limit: '1mb' }));

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
});
app.use(limiter);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/courses', coursesRoutes);
app.use('/api/assignments', assignmentsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/ai', aiContentRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/discussions', authenticate, discussionsRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api/teacher-notes', teacherNotesRoutes);
app.use('/api/notes', notesRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/parent', parentRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/classroom', classroomRoutes);
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

app.use(notFound);
app.use(errorHandler);

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
  startDigestEmailWorker();
  // pgvector + KnowledgeChunk can't be created by `prisma migrate deploy`, so
  // they are ensured here rather than left to a manual psql step nobody
  // remembers on a fresh database. Idempotent, and never blocks serving traffic.
  void ensureRagSchema();
});

const shutdown = async (signal: string) => {
  console.log(`Received ${signal}, shutting down gracefully...`);
  await prisma.$disconnect();
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
