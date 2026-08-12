import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';

// Never return the full User row from a join: password hashes must never
// leave the server. Only identity fields are safe to expose.
const instructorSelect = {
  id: true,
  name: true,
  photoUrl: true,
};

const router = Router();

// Get all courses
router.get('/', async (req, res: Response) => {
  try {
    const courses = await prisma.course.findMany({
      include: { instructor: { select: instructorSelect } }
    });
    res.json(courses);
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
