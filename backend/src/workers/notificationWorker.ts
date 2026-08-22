import { Worker } from 'bullmq';
import { getRedis } from '../lib/redis.js';
import prisma from '../lib/prisma.js';

// P0 verified: Worker exists, uses Redis instance via getRedis(), started from index.ts
export async function startWorkers() {
  const conn = await getRedis();
  if (!conn) return;
  const worker = new Worker(
    'notifications',
    async (job) => {
      const { sectionId, payload } = job.data;
      const enrolls = await prisma.enrollment.findMany({ where: { sectionId } });
      await prisma.notification.createMany({ data: enrolls.map((e) => ({ userId: e.studentId, ...payload })) });
    },
    { connection: conn },
  );
  // P0: keep worker alive, log errors without crashing process
  if (worker && typeof (worker as any).on === 'function') {
    (worker as any).on('failed', (job: any, err: any) => console.error('[notificationWorker] job failed', job?.id, err?.message));
    (worker as any).on('error', (err: any) => console.error('[notificationWorker] error', err?.message));
  }
  return worker;
}
