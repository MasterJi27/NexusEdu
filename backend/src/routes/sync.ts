import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { logActivity } from '../lib/logger';

// Offline outbox flush. The app queues work it couldn't do while offline
// (notes created, quizzes taken without connectivity) and posts the whole
// queue here when it reconnects. Each item is processed independently and
// answered with its own ok/error so the client can drop exactly the items
// that landed.
const router = Router();

const notePayloadSchema = z.object({
  title: z.string().trim().min(1).max(200),
  content: z.string().max(50000),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

const quizResultSchema = z.object({
  title: z.string().trim().min(1).max(200),
  score: z.number().int().min(0).max(1000),
  total: z.number().int().min(1).max(1000),
  percent: z.number().min(0).max(100).optional(),
  takenAt: z.string().datetime().optional(),
});

const itemSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('note'), payload: notePayloadSchema }),
  z.object({ type: z.literal('quiz_result'), payload: quizResultSchema }),
]);

const queueSchema = z.object({
  items: z.array(itemSchema).min(1).max(100),
});

router.post('/queue', authenticate, validateBody(queueSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const results: Array<Record<string, unknown>> = [];
    for (const item of req.body.items) {
      try {
        if (item.type === 'note') {
          const note = await prisma.studentNote.create({
            data: { userId: req.user!.id, ...item.payload },
            select: { id: true },
          });
          results.push({ type: 'note', ok: true, id: note.id });
        } else {
          const percent =
            item.payload.percent ??
            Math.round((item.payload.score / item.payload.total) * 100);
          await logActivity(req.user!.id, 'QUIZ_COMPLETED', {
            title: item.payload.title,
            score: item.payload.score,
            total: item.payload.total,
            percent,
            takenAt: item.payload.takenAt,
            source: 'offline_queue',
          });
          results.push({ type: 'quiz_result', ok: true });
        }
      } catch (error: any) {
        console.error('Sync queue item error:', error);
        results.push({
          type: item.type,
          ok: false,
          error: error?.code === 'P2002' ? 'duplicate' : 'failed',
        });
      }
    }
    res.status(200).json({ results });
  } catch (error) {
    console.error('Sync queue error:', error);
    res.status(500).json({ error: 'Failed to process sync queue.' });
  }
});

export default router;
