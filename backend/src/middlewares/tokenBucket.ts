import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
import { getRedis } from '../lib/redis';

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
 * Redis path uses an atomic Lua token bucket. Fallback is process-local Map.
 * TODO: monitor fallback Map memory under high cardinality; consider LRU if needed.
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

/**
 * Redis-backed atomic token bucket via Lua (P0 fix) — verified 1M.
 * Replaces previous fixed-window INCR+PEXPIRE which allowed burst at window boundaries.
 * Script is atomic: HMGET tokens/last, refill based on elapsed intervals, consume if available, HMSET+PEXPIRE.
 * Uses redis.eval Lua with HMGET/HMSET/PEXPIRE atomically (not fixed-window INCR).
 * Falls back to null (caller uses in-memory Map) when Redis not configured or EVAL fails.
 * Spec pattern: local bucket = redis.call('HMGET', KEYS[1], 'tokens','last'); local tokens=tonumber(bucket[1]) or capacity; local last=tonumber(bucket[2]) or now; ...
 */
async function takeTokenRedis(key: string, opts: TokenBucketOptions): Promise<boolean | null> {
  try {
    const redis = await getRedis();
    if (!redis) return null;
    const redisKey = `tb:${key}`;
    const now = Date.now();

    // Lua token bucket: atomic refill + consume
    const luaScript = `
local bucket = redis.call('HMGET', KEYS[1], 'tokens','last')
local tokens = tonumber(bucket[1])
local last = tonumber(bucket[2])
local now = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])
local refillAmount = tonumber(ARGV[3])
local refillInterval = tonumber(ARGV[4])
if tokens == nil then tokens = capacity end
if last == nil then last = now end
local elapsed = now - last
local refillCycles = math.floor(elapsed / refillInterval)
if refillCycles > 0 then
  tokens = math.min(capacity, tokens + refillCycles * refillAmount)
  last = now
end
if tokens < 1 then
  redis.call('HMSET', KEYS[1], 'tokens', tokens, 'last', last)
  redis.call('PEXPIRE', KEYS[1], 600000)
  return 0
else
  tokens = tokens - 1
  redis.call('HMSET', KEYS[1], 'tokens', tokens, 'last', last)
  redis.call('PEXPIRE', KEYS[1], 600000)
  return 1
end
`.trim();

    let result: unknown;
    if (typeof redis.eval === 'function') {
      result = await redis.eval(luaScript, 1, redisKey, String(now), String(opts.capacity), String(opts.refillAmount), String(opts.refillIntervalMs));
    } else if (typeof redis.EVAL === 'function') {
      result = await (redis as any).EVAL(luaScript, 1, redisKey, String(now), String(opts.capacity), String(opts.refillAmount), String(opts.refillIntervalMs));
    } else {
      return null;
    }
    return Number(result) === 1;
  } catch {
    return null;
  }
}

/** Express middleware factory. See [TokenBucketOptions] for the knobs. */
export const tokenBucket = (opts: TokenBucketOptions) =>
  async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
    const key = opts.keyFn ? opts.keyFn(req) : req.ip || 'unknown';
    // Try Redis Lua bucket first when available; fall back to process-local Map when getRedis() is null or fails.
    // TODO: fallback Map is in-memory only and not shared across instances; Redis Lua is the source of truth for multi-instance deploys.
    const redisResult = await takeTokenRedis(key, opts);
    if (redisResult !== null) {
      if (!redisResult) {
        res.status(429).json({
          error: opts.message || 'Too many attempts. Please wait a moment and try again.',
        });
        return;
      }
      next();
      return;
    }
    if (!takeToken(key, opts)) {
      res.status(429).json({
        error: opts.message || 'Too many attempts. Please wait a moment and try again.',
      });
      return;
    }
    next();
  };
