import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { validateBody } from '../middlewares/validate';

const router = Router();

// Crash reports can come from signed-out users (e.g. a crash during
// onboarding), so this stays unauthenticated — the rate limiter is the abuse
// control instead of requireRole/authenticate.
const reportLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { error: 'Too many error reports from this device, please try again later.' },
});

const errorReportSchema = z.object({
  message: z.string().max(2000),
  stack: z.string().max(8000).optional(),
  fatal: z.boolean().optional(),
  appVersion: z.string().max(50).optional(),
  platform: z.string().max(50).optional(),
});

/**
 * Relays client-side crashes into the same console-based logging pipeline
 * Application Insights already auto-collects server-side (see index.ts) —
 * no separate crash-reporting SDK/account needed for this to be real.
 */
router.post('/', reportLimiter, validateBody(errorReportSchema), (req, res) => {
  const { message, stack, fatal, appVersion, platform } = req.body;
  console.error('[client-error]', JSON.stringify({ message, stack, fatal, appVersion, platform }));
  res.status(204).end();
});

export default router;
