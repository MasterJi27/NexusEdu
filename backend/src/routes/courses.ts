import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';
import { parsePagination } from '../lib/pagination';

// Never return the full User row from a join: password hashes must never
// leave the server. Only identity fields are safe to expose.
const instructorSelect = {
  id: true,
  name: true,
  photoUrl: true,
};

const router = Router();

// Get all courses — 1M: cursor pagination guards unbounded table scan (max 20 enforced)
router.get('/', async (req, res: Response) => {
  try {
    // Validation: limit must be 1-20, cursor must be a string ID if provided
    if (req.query.limit !== undefined) {
      const parsed = Number(req.query.limit);
      if (!Number.isInteger(parsed) || parsed < 1 || parsed > 20) {
        res.status(400).json({ error: 'limit must be an integer between 1 and 20' });
        return;
      }
    }
    if (req.query.cursor !== undefined && typeof req.query.cursor !== 'string') {
      res.status(400).json({ error: 'cursor must be a string' });
      return;
    }
    const { limit, cursor } = parsePagination(req.query as any, 20);
    const courses = await prisma.course.findMany({
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor as string } : undefined,
      orderBy: { createdAt: 'desc' },
      include: { instructor: { select: instructorSelect } },
    });
    const nextCursor = courses.length === limit ? courses[courses.length - 1].id : null;
    res.json({ items: courses, nextCursor });
  } catch (error) {
    console.error('Fetch courses error:', error);
    res.status(500).json({ error: 'Failed to fetch courses' });
  }
});

// Get a single course by ID
router.get('/:id', async (req, res: Response) => {
  try {
    const course = await prisma.course.findUnique({
      where: { id: req.params.id },
      include: {
        modules: {
          include: { lessons: true, assignments: true }
        },
        instructor: { select: instructorSelect }
      }
    });
    if (!course) {
      res.status(404).json({ error: 'Course not found' });
      return;
    }
    res.json(course);
  } catch (error) {
    console.error('Fetch course error:', error);
    res.status(500).json({ error: 'Failed to fetch course' });
  }
});

const createCourseSchema = z.object({
  title: z.string().trim().min(1).max(200),
  description: z.string().max(2000).optional(),
  thumbnailUrl: z.string().url().optional(),
});

// Create a new course (Teacher/Admin only)
router.post('/', authenticate, requireRole('teacher', 'admin'), validateBody(createCourseSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { title, description, thumbnailUrl } = req.body;
    const course = await prisma.course.create({
      data: {
        title,
        description,
        thumbnailUrl,
        instructorId: req.user!.id,
      }
    });
    res.status(201).json(course);
  } catch (error) {
    console.error('Create course error:', error);
    res.status(500).json({ error: 'Failed to create course' });
  }
});

export default router;
