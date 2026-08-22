import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole, isOwnerOrAdmin } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';
import { enqueueRagIndex, indexSource, deleteSourceIndex } from '../services/ragService.js';
import { parsePagination } from '../lib/pagination.js';

const router = Router();

const noteSelect = {
  id: true, title: true, content: true, gradeLevel: true, subject: true,
  topic: true, isPublished: true, createdAt: true, updatedAt: true,
  teacher: { select: { id: true, name: true, photoUrl: true } },
};

// List notes visible to the current user.
// Teachers see their own notes (published or not). Students/parents see only
// published notes matching their own gradeLevel (falls back to all published
// notes for the requested grade if a grade query param is supplied).
// 1M: cursor pagination with take limit guards unbounded findMany.
router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { limit, cursor } = parsePagination(req.query, 50);
    const pagination = {
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor as string } : undefined,
    };

    if (req.user!.role === 'teacher' || req.user!.role === 'admin') {
      const notes = await prisma.teacherNote.findMany({
        where: { teacherId: req.user!.id },
        orderBy: { createdAt: 'desc' },
        select: noteSelect,
        ...pagination,
      });
      const nextCursor = notes.length === limit ? notes[notes.length - 1].id : null;
      res.status(200).json({ items: notes, nextCursor });
      return;
    }

    const gradeLevel = (req.query.gradeLevel as string) || (
      await prisma.user.findUnique({ where: { id: req.user!.id }, select: { gradeLevel: true } })
    )?.gradeLevel;

    if (!gradeLevel) {
      res.status(200).json({ items: [], nextCursor: null });
      return;
    }

    const subject = req.query.subject as string | undefined;
    const notes = await prisma.teacherNote.findMany({
      where: {
        gradeLevel,
        isPublished: true,
        ...(subject ? { subject } : {}),
      },
      orderBy: { createdAt: 'desc' },
      select: noteSelect,
      ...pagination,
    });
    const nextCursor = notes.length === limit ? notes[notes.length - 1].id : null;
    res.status(200).json({ items: notes, nextCursor });
  } catch (error: any) {
    if (error?.status === 400) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('List teacher notes error:', error);
    res.status(500).json({ error: 'Failed to fetch notes.' });
  }
});

const createNoteSchema = z.object({
  title: z.string().trim().min(1).max(200),
  content: z.string().trim().min(1).max(20000),
  gradeLevel: z.string().trim().min(1).max(100),
  subject: z.string().trim().min(1).max(50),
  topic: z.string().trim().max(100).optional(),
  isPublished: z.boolean().optional(),
});

router.post('/', authenticate, requireRole('teacher', 'admin'), validateBody(createNoteSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { title, content, gradeLevel, subject, topic, isPublished } = req.body;
    const note = await prisma.teacherNote.create({
      data: {
        title, content, gradeLevel, subject, topic,
        isPublished: isPublished ?? true,
        teacherId: req.user!.id,
      },
      select: noteSelect,
    });
    // Best-effort RAG indexing via queue when available, fallback to direct index.
    void enqueueRagIndex({
      userId: req.user!.id,
      sourceType: 'teacher_note',
      sourceId: note.id,
      title: note.title,
      content: note.content,
    }).then((enqueued) => { if (!enqueued) void indexSource({ userId: req.user!.id, sourceType: 'teacher_note', sourceId: note.id, title: note.title, content: note.content }); });
    res.status(201).json(note);
  } catch (error) {
    console.error('Create teacher note error:', error);
    res.status(500).json({ error: 'Failed to create note.' });
  }
});

router.delete('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const note = await prisma.teacherNote.findUnique({ where: { id: req.params.id as string } });
    if (!note) {
      res.status(404).json({ error: 'Note not found.' });
      return;
    }
    if (!isOwnerOrAdmin(note.teacherId, req.user)) {
      res.status(403).json({ error: 'You can only delete your own notes.' });
      return;
    }
    await prisma.teacherNote.delete({ where: { id: note.id } });
    void deleteSourceIndex('teacher_note', note.id);
    res.status(204).end();
  } catch (error) {
    console.error('Delete teacher note error:', error);
    res.status(500).json({ error: 'Failed to delete note.' });
  }
});

export default router;
