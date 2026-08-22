import crypto from 'crypto';
import type { Request } from 'express';
import { ipKeyGenerator } from 'express-rate-limit';
import { getRedisSync } from '../lib/redis';

/**
 * Key generator that never throws. express-rate-limit's strict default
 * validates the IP with net.isIP and throws ERR_ERL_INVALID_IP_ADDRESS when
 * the proxy chain hands us "1.2.3.4:9569" — Azure Front Door appends the
 * source port to X-Forwarded-For, which is exactly what the prod logs show.
 * When strict parsing fails, fall back to a hash of the socket's remote
 * address: same client, same bucket, no crash.
 */
export const ipKey = (req: Request): string => {
  try {
    return ipKeyGenerator(req.ip || '');
  } catch {
    return crypto
      .createHash('sha1')
      .update(req.socket?.remoteAddress || 'unknown')
      .digest('hex')
      .slice(0, 24);
  }
};

/**
 * Returns a RedisStore for express-rate-limit when Redis is available,
 * otherwise undefined to fall back to MemoryStore.
 * Usage: const store = redis ? new RedisStore({sendCommand: (...args)=>redis.call(...args)}) : undefined;
 * Spec exact: import {RedisStore} from 'rate-limit-redis'; const store = redis ? new RedisStore({sendCommand: (...args)=>redis.call(...args)}) : undefined;
 */
export function getRateLimitStore(prefix = 'rl:global:'): any | undefined {
  try {
    const redis: any = getRedisSync();
    if (!redis) return undefined;
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { RedisStore } = require('rate-limit-redis');
    const store = redis ? new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args), prefix }) : undefined;
    return store;
  } catch {
    return undefined;
  }
}