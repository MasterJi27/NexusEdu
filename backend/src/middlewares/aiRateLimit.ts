import rateLimit from 'express-rate-limit';
import { AuthRequest } from './auth';
import { ipKey } from './rateLimit';
import { getRedisSync } from '../lib/redis';

/**
 * Per-user rate limit for any route that calls a paid/quota-limited external
 * AI provider (Groq, Azure AI) directly, so one account can't burn the app's
 * shared provider key for everyone else. Falls back to IP for the rare
 * unauthenticated caller. Distinct from the token-budget check in
 * services/aiService.ts (consumeAiRequest) — this is a blunt per-route
 * throttle, not the business-logic quota.
 */
// Use RedisStore when Redis is available, fallback to MemoryStore otherwise.
// Pattern: import {RedisStore} from 'rate-limit-redis'; const store = redis ? new RedisStore({sendCommand: (...args)=>redis.call(...args)}) : undefined;
// Spec exact: import {RedisStore} from 'rate-limit-redis'; const store = redis ? new RedisStore({sendCommand: (...args)=>redis.call(...args)}) : undefined;
let aiRedisStore: any | undefined;
try {
  const redis: any = getRedisSync();
  if (redis) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { RedisStore } = require('rate-limit-redis');
    const store = redis ? new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args), prefix: 'rl:ai:' }) : undefined;
    aiRedisStore = store;
  }
} catch {
  aiRedisStore = undefined;
}

export const aiRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
  message: { error: 'Too many AI requests. Please slow down and try again in a few minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
  ...(aiRedisStore ? { store: aiRedisStore } : {}),
  keyGenerator: (req) => {
    const authReq = req as AuthRequest;
    if (authReq.user?.id) return `user:${authReq.user.id}`;
    return ipKey(req);
  },
});
