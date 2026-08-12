import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';

// A student's own notes. Every row is scoped to the authenticated user, so
// there is no id guessing: the where clause always includes userId.
const router = Router();

const noteSelect = { id: true, title: true, content: true, latitude: true, longitude: true, createdAt: true, updatedAt: true };

router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const notes = await prisma.studentNote.findMany({
      where: { userId: req.user!.id },
      orderBy: { updatedAt: 'desc' },
      select: noteSelect,
    });
    res.status(200).json(notes);
  } catch (error) {
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
  } catch (error) {
    // Prisma throws P2025 when the row does not exist for this user.
    res.status(404).json({ error: 'Note not found.' });
  }
});

router.delete('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.studentNote.delete({
      where: { id: req.params.id as string, userId: req.user!.id },
    });
    res.status(204).end();
  } catch (error) {
    res.status(404).json({ error: 'Note not found.' });
  }
});

export default router;
