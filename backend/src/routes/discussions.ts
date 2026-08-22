import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { enqueueRagIndex, indexSource } from '../services/ragService.js';
import { parsePagination } from '../lib/pagination.js';

const router = Router();

const authorSelect = { select: { id: true, name: true, photoUrl: true } };

router.get('/:courseId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const courseId = req.params.courseId as string;
    // Pagination enforced max 20 with validation (mirrors courses route)
    if ((req.query as any).limit !== undefined) {
      const parsed = Number((req.query as any).limit);
      if (!Number.isInteger(parsed) || parsed < 1 || parsed > 20) {
        res.status(400).json({ error: 'limit must be an integer between 1 and 20' });
        return;
      }
    }
    if ((req.query as any).cursor !== undefined && typeof (req.query as any).cursor !== 'string') {
      res.status(400).json({ error: 'cursor must be a string' });
      return;
    }
    const { limit, cursor } = parsePagination(req.query as any, 20);
    const threads = await prisma.discussion.findMany({
      where: { courseId },
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor as string } : undefined,
      include: {
        author: authorSelect,
        replies: { include: { author: authorSelect }, orderBy: { createdAt: 'asc' } },
      },
      orderBy: { createdAt: 'desc' },
    });
    const nextCursor = threads.length === limit ? threads[threads.length - 1].id : null;
    // Return paginated shape when pagination is used, but keep backwards compat for plain array consumers
    const wantsPagination = (req.query as any).limit !== undefined || (req.query as any).cursor !== undefined;
    if (wantsPagination) {
      res.json({ items: threads, nextCursor });
    } else {
      // Enforce max 20 even for unpaginated callers (defense against unbounded scan)
      res.json(threads);
    }
  } catch (error: any) {
    if (error?.status === 400) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('Fetch discussions error:', error);
    res.status(500).json({ error: 'Failed to fetch discussions' });
  }
});

const createThreadSchema = z.object({
  title: z.string().trim().min(1).max(200),
  content: z.string().trim().min(1).max(5000),
});

router.post('/:courseId', validateBody(createThreadSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const courseId = req.params.courseId as string;
    const { title, content } = req.body;

    const thread = await prisma.discussion.create({
      data: { courseId, title, content, authorId: req.user!.id },
      include: { author: authorSelect, replies: true },
    });

    // Best-effort RAG indexing via queue when available, fallback to direct.
    void enqueueRagIndex({
      userId: req.user!.id,
      sourceType: 'discussion',
      sourceId: thread.id,
      title: thread.title,
      content: thread.content,
    }).then((enqueued) => { if (!enqueued) void indexSource({ userId: req.user!.id, sourceType: 'discussion', sourceId: thread.id, title: thread.title, content: thread.content }); });

    res.status(201).json(thread);
  } catch (error) {
    console.error('Create discussion error:', error);
    res.status(500).json({ error: 'Failed to create discussion' });
  }
});

const createReplySchema = z.object({
  content: z.string().trim().min(1).max(5000),
});

router.post('/:courseId/:threadId/reply', validateBody(createReplySchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const threadId = req.params.threadId as string;
    const { content } = req.body;

    const thread = await prisma.discussion.findUnique({ where: { id: threadId } });
    if (!thread) {
      res.status(404).json({ error: 'Thread not found' });
      return;
    }

    const reply = await prisma.reply.create({
      data: { discussionId: threadId, content, authorId: req.user!.id },
      include: { author: authorSelect },
    });

    // Best-effort RAG indexing for the reply via queue, fallback to direct.
    void enqueueRagIndex({
      userId: req.user!.id,
      sourceType: 'discussion_reply',
      sourceId: reply.id,
      title: `Reply to: ${thread.title}`,
      content: reply.content,
    }).then((enqueued) => { if (!enqueued) void indexSource({ userId: req.user!.id, sourceType: 'discussion_reply', sourceId: reply.id, title: `Reply to: ${thread.title}`, content: reply.content }); });

    res.status(201).json(reply);
  } catch (error) {
    console.error('Create reply error:', error);
    res.status(500).json({ error: 'Failed to create reply' });
  }
});

export default router;
