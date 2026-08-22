import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { parsePagination } from '../lib/pagination.js';

// A student's own notes. Every row is scoped to the authenticated user, so
// there is no id guessing: the where clause always includes userId.
const router = Router();

const noteSelect = { id: true, title: true, content: true, latitude: true, longitude: true, createdAt: true, updatedAt: true };

router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { limit, cursor } = parsePagination(req.query, 50);
    const notes = await prisma.studentNote.findMany({
      where: { userId: req.user!.id },
      orderBy: { updatedAt: 'desc' },
      select: noteSelect,
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor as string } : undefined,
    });
    const nextCursor = notes.length === limit ? notes[notes.length - 1].id : null;
    res.status(200).json({ items: notes, nextCursor });
  } catch (error: any) {
    if (error?.status === 400) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('List notes error:', error);
    res.status(500).json({ error: 'Failed to fetch notes.' });
  }
});

const noteSchema = z.object({
  title: z.string().trim().min(1).max(200),
  content: z.string().max(50000),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

router.post('/', authenticate, validateBody(noteSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const note = await prisma.studentNote.create({
      data: { userId: req.user!.id, ...req.body },
      select: noteSelect,
    });
    res.status(201).json(note);
  } catch (error) {
    console.error('Create note error:', error);
    res.status(500).json({ error: 'Failed to save note.' });
  }
});

const updateSchema = noteSchema.partial();

router.put('/:id', authenticate, validateBody(updateSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const note = await prisma.studentNote.update({
      where: { id: req.params.id as string, userId: req.user!.id },
      data: req.body,
      select: noteSelect,
    });
    res.status(200).json(note);
  } catch (error: any) {
    // P2025 = the row does not exist for this user; anything else (DB down,
    // connection loss) is a real server problem and must not masquerade as
    // "not found" — that hid outages as client-visible 404s.
    if (error?.code === 'P2025') {
      res.status(404).json({ error: 'Note not found.' });
      return;
    }
    console.error('Update note error:', error);
    res.status(500).json({ error: 'Failed to update note.' });
  }
});

router.delete('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.studentNote.delete({
      where: { id: req.params.id as string, userId: req.user!.id },
    });
    res.status(204).end();
  } catch (error: any) {
    if (error?.code === 'P2025') {
      res.status(404).json({ error: 'Note not found.' });
      return;
    }
    console.error('Delete note error:', error);
    res.status(500).json({ error: 'Failed to delete note.' });
  }
});

export default router;
