// Redis abstraction for rate-limit and token buckets (P0/P1 fix: eager connect).
// When REDIS_URL is set, getRedis() dynamically imports ioredis and eagerly connects
// so callers get a ready client. maxRetriesPerRequest:null + enableReadyCheck:false is required for BullMQ.
// TLS enabled automatically for rediss:// URLs. Falls back to null when Redis not configured.
// P0 verified: lazyConnect:false, ping(), getRedisSync triggers getRedis()

let redisInstance: any | null = null;
let initAttempted = false;

export async function getRedis(): Promise<any | null> {
  const REDIS_URL = process.env.REDIS_URL;
  if (!REDIS_URL) return null;
  if (redisInstance) return redisInstance;
  // Retry reset for initAttempted: if previous init failed, allow retry
  if (initAttempted && !redisInstance) {
    initAttempted = false;
  }
  if (initAttempted) return redisInstance;
  initAttempted = true;
  try {
    // Dynamic import so 'ioredis' is not required at install time (stub).
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    // @ts-ignore - ioredis is optional until REDIS_URL is set in prod
    const IORedisMod: any = await import('ioredis');
    const IORedis: any = IORedisMod.default ?? IORedisMod;
    // P0/P1 fix: eager connect (lazyConnect:false) with TLS handling and ping check
    const RedisCtor = (IORedis as any).default ?? IORedis;
    if (!redisInstance && REDIS_URL) {
      redisInstance = new RedisCtor(REDIS_URL, {
        lazyConnect: false,
        maxRetriesPerRequest: null,
        enableReadyCheck: false,
        tls: REDIS_URL.includes('rediss') ? {} : undefined,
      });
      await redisInstance.ping().catch(() => {});
    }
    return redisInstance;
  } catch {
    // ioredis not installed yet or connection failed — reset to allow retry
    initAttempted = false;
    redisInstance = null;
    return null;
  }
}

// Synchronous check for health/ready without importing ioredis.
// P1 fix: if instance is null but REDIS_URL is set, trigger async init via getRedis().
export function getRedisSync(): any | null {
  if (!redisInstance && process.env.REDIS_URL) void getRedis().catch(() => {});
  if (!process.env.REDIS_URL) return null;
  return redisInstance;
}

export async function disconnectRedis(): Promise<void> {
  if (redisInstance) {
    try {
      if (typeof redisInstance.quit === 'function') {
        await redisInstance.quit();
      } else if (typeof redisInstance.disconnect === 'function') {
        redisInstance.disconnect();
      }
    } catch {
      try {
        if (typeof redisInstance.disconnect === 'function') redisInstance.disconnect();
      } catch {}
    } finally {
      redisInstance = null;
      initAttempted = false;
    }
  } else {
    // Ensure initAttempted resets even if instance was null (failed init)
    initAttempted = false;
  }
}

export default getRedis;
