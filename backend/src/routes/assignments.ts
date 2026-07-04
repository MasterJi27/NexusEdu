import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const router = Router();
const prisma = new PrismaClient();

// Get assignments for a module
router.get('/module/:moduleId', async (req: Request, res: Response) => {
  try {
    const filter: any = { moduleId: req.params.moduleId };
    if (req.query.courseId) {
      filter.courseId = req.query.courseId as string;
    }
    const assignments = await prisma.assignment.findMany({
      where: filter
    });
    res.json(assignments);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch assignments' });
  }
});

// Submit an assignment
router.post('/submit', async (req: Request, res: Response) => {
  try {
    const { assignmentId, studentId, content, fileUrl } = req.body;
    const submission = await prisma.submission.create({
      data: {
        assignmentId,
        studentId,
        content,
        fileUrl
      }
    });
    res.status(201).json(submission);
  } catch (error) {
    res.status(500).json({ error: 'Failed to submit assignment' });
  }
});

export default router;
