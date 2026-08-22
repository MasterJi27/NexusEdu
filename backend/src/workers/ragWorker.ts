import { Worker } from 'bullmq';
import { getRedis } from '../lib/redis.js';

export async function startRagWorker() {
  const conn = await getRedis();
  if (!conn) return;
  new Worker(
    'rag-index',
    async (job) => {
      const { indexSource } = await import('../services/ragService.js');
      await indexSource(job.data);
    },
    { connection: conn },
  );
}

export async function startWorkers() {
  return startRagWorker();
}
