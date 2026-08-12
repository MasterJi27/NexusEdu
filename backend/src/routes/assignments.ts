import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';

const router = Router();

// Get assignments for a module
router.get('/module/:moduleId', async (req, res: Response) => {
  try {
    const assignments = await prisma.assignment.findMany({
      where: { moduleId: req.params.moduleId }
    });
    res.json(assignments);
  } catch (error) {
    console.error('Fetch assignments error:', error);
    res.status(500).json({ error: 'Failed to fetch assignments' });
  }
});

const submitAssignmentSchema = z.object({
  assignmentId: z.string().min(1),
  content: z.string().max(20000).optional(),
  fileUrl: z.string().url().optional(),
});

// Submit an assignment
router.post('/submit', authenticate, validateBody(submitAssignmentSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { assignmentId, content, fileUrl } = req.body;
    const submission = await prisma.submission.create({
      data: {
        assignmentId,
        studentId: req.user!.id,
        content,
        fileUrl
      }
    });
    res.status(201).json(submission);
  } catch (error) {
    console.error('Submit assignment error:', error);
    res.status(500).json({ error: 'Failed to submit assignment' });
  }
});

export default router;
