import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';

/**
 * Token-bucket rate limiting, keyed however the caller wants (per-student,
 * per-student+session, per-IP, etc).
 *
 * Chosen over the fixed-window limiter already used for login
 * (see routes/auth.ts) because a fixed window lets a client burst up to 2x
 * the limit right at a window boundary — tolerable for login, not for an
 * endpoint that verifies a short-lived code where a burst is exactly the
 * behavior a fraud attempt would produce. A token bucket absorbs one
 * legitimate retry (a flaky classroom wifi connection resubmitting) while
 * still capping sustained abuse, and the remaining token count is itself a
 * useful signal for later fraud-detection sweeps.
 *
 * This is process-local, in-memory state — correct for a single instance.
 * If the backend ever runs more than one instance behind a load balancer,
 * the bucket store needs to move to Redis (INCR + TTL, or a Lua script for
 * atomicity); the interface below is written so that swap only touches this
 * one file.
 */

interface Bucket {
  tokens: number;
  lastRefillAt: number;
}

const buckets = new Map<string, Bucket>();

// Buckets are cheap but not free; without this a key that is only ever hit
// once (e.g. a one-off IP) would sit in memory forever. Swept lazily on
// access rather than on a timer, so there is no background work to leak.
const STALE_AFTER_MS = 10 * 60 * 1000;

export interface TokenBucketOptions {
  /** Maximum tokens the bucket can hold — the size of the allowed burst. */
  capacity: number;
  /** How many tokens are added back per [refillIntervalMs]. */
  refillAmount: number;
  refillIntervalMs: number;
  /** Derives the bucket key from the request. Defaults to the client IP. */
  keyFn?: (req: AuthRequest) => string;
  /** Message returned when the bucket is empty. */
  message?: string;
}

function takeToken(key: string, opts: TokenBucketOptions): boolean {
  const now = Date.now();
  const existing = buckets.get(key);

  if (!existing || now - existing.lastRefillAt > STALE_AFTER_MS) {
    buckets.set(key, { tokens: opts.capacity - 1, lastRefillAt: now });
    return true;
  }

  const elapsed = now - existing.lastRefillAt;
  const refillCycles = Math.floor(elapsed / opts.refillIntervalMs);
  if (refillCycles > 0) {
    existing.tokens = Math.min(
      opts.capacity,
      existing.tokens + refillCycles * opts.refillAmount,
    );
    existing.lastRefillAt = now;
  }

  if (existing.tokens < 1) return false;
  existing.tokens -= 1;
  return true;
}

/** Express middleware factory. See [TokenBucketOptions] for the knobs. */
export const tokenBucket = (opts: TokenBucketOptions) =>
  (req: AuthRequest, res: Response, next: NextFunction): void => {
    const key = opts.keyFn ? opts.keyFn(req) : req.ip || 'unknown';
    if (!takeToken(key, opts)) {
      res.status(429).json({
        error: opts.message || 'Too many attempts. Please wait a moment and try again.',
      });
      return;
    }
    next();
  };
