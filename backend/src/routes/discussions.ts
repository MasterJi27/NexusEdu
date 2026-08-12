import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { indexSource } from '../services/ragService';

const router = Router();

const authorSelect = { select: { id: true, name: true, photoUrl: true } };

router.get('/:courseId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const courseId = req.params.courseId as string;
    const threads = await prisma.discussion.findMany({
      where: { courseId },
      include: {
        author: authorSelect,
        replies: { include: { author: authorSelect }, orderBy: { createdAt: 'asc' } },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json(threads);
  } catch (error) {
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

    // Best-effort RAG indexing; failures never block the thread creation.
    void indexSource({
      userId: req.user!.id,
      sourceType: 'discussion',
      sourceId: thread.id,
      title: thread.title,
      content: thread.content,
    });

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

    // Best-effort RAG indexing for the reply as its own chunk.
    void indexSource({
      userId: req.user!.id,
      sourceType: 'discussion_reply',
      sourceId: reply.id,
      title: `Reply to: ${thread.title}`,
      content: reply.content,
    });

    res.status(201).json(reply);
  } catch (error) {
    console.error('Create reply error:', error);
    res.status(500).json({ error: 'Failed to create reply' });
  }
});

export default router;
