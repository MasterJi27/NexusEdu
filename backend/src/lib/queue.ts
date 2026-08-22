import { getRedis } from './redis';
import prisma from './prisma';

let notificationQueue: any | null = null;
let initAttempted = false;

/**
 * Returns a BullMQ Queue for notification fan-out when REDIS_URL is set,
 * otherwise null (caller should fallback to direct DB createMany).
 * Uses lazy dynamic import so bullmq is optional until Redis is configured.
 */
let ragQueue: any | null = null;
let ragInitAttempted = false;

/**
 * Returns a BullMQ Queue for RAG indexing jobs when REDIS_URL is set.
 * When Redis is absent, callers should fallback to direct indexSource() call.
 * Queue wiring ensures heavy embedding work does not block request path.
 */
export async function getRagQueue(): Promise<any | null> {
  if (ragInitAttempted) return ragQueue;
  if (!process.env.REDIS_URL) return null;
  ragInitAttempted = true;
  try {
    const { Queue } = await import('bullmq');
    const r: any = await getRedis();
    if (!r) return null;
    ragQueue = new Queue('rag-index', {
      connection: r,
      defaultJobOptions: {
        attempts: 3,
        backoff: { type: 'exponential', delay: 1000 },
        removeOnComplete: 100,
        removeOnFail: 50,
      },
    });
    if (ragQueue && typeof ragQueue.on === 'function') {
      ragQueue.on('error', (err: unknown) => console.error('[queue] rag queue error:', err));
    }
    return ragQueue;
  } catch (err) {
    console.error('[queue] Failed to init BullMQ rag queue (fallback to direct index):', err);
    return null;
  }
}

export function getRagQueueSync(): any | null {
  if (!process.env.REDIS_URL) return null;
  return ragQueue;
}

export async function getNotificationQueue(): Promise<any | null> {
  if (initAttempted) return notificationQueue;
  if (!process.env.REDIS_URL) return null;
  initAttempted = true;
  try {
    // Dynamic import keeps bullmq optional until deployed with Redis
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { Queue } = await import('bullmq');
    // P0 verified: use Redis instance from getRedis() for BullMQ connection (not new Redis)
    const r: any = await getRedis();
    if (!r) return null;
    // BullMQ needs maxRetriesPerRequest:null and enableReadyCheck:false – ensured in redis.ts (lazyConnect:false)
    notificationQueue = new Queue('notifications', {
      connection: r,
      defaultJobOptions: {
        attempts: 3,
        backoff: { type: 'exponential', delay: 1000 },
        removeOnComplete: 100,
        removeOnFail: 50,
      },
    });
    // Add a lightweight error handler so unhandled error events never crash the process
    if (notificationQueue && typeof notificationQueue.on === 'function') {
      notificationQueue.on('error', (err: unknown) => console.error('[queue] notification queue error:', err));
    }
    return notificationQueue;
  } catch (err) {
    console.error('[queue] Failed to init BullMQ notification queue (fallback to direct DB):', err);
    return null;
  }
}

export function getNotificationQueueSync(): any | null {
  if (!process.env.REDIS_URL) return null;
  return notificationQueue;
}

export async function disconnectQueue(): Promise<void> {
  if (notificationQueue) {
    try {
      await notificationQueue.close();
    } catch {}
    notificationQueue = null;
    initAttempted = false;
  }
  if (ragQueue) {
    try {
      await ragQueue.close();
    } catch {}
    ragQueue = null;
    ragInitAttempted = false;
  }
}

export async function startWorkers(): Promise<void> {
  // P0 verified: Worker exists for notifications, uses Redis instance from getRedis()
  const { Worker } = await import('bullmq');
  const q = await getNotificationQueue();
  if (q) {
    new Worker(
      'notifications',
      async (job: any) => {
        const { sectionId, payload } = job.data;
        const enrolls = await prisma.enrollment.findMany({ where: { sectionId } });
        await prisma.notification.createMany({ data: enrolls.map((e: any) => ({ userId: e.studentId, ...payload })) });
      },
      { connection: await getRedis() },
    );
  }
  const rq = await getRagQueue();
  if (rq) {
    new Worker(
      'rag-index',
      async (job: any) => {
        const { indexSource } = await import('../services/ragService.js');
        await indexSource(job.data);
      },
      { connection: await getRedis() },
    );
  }
}

export default getNotificationQueue;
