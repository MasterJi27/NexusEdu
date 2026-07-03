import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const router = Router();
const prisma = new PrismaClient();

// Get all courses
router.get('/', async (req: Request, res: Response) => {
  try {
    const courses = await prisma.course.findMany({
      include: { instructor: true }
    });
    res.json(courses);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch courses' });
  }
});

// Get a single course by ID
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const course = await prisma.course.findUnique({
      where: { id: req.params.id },
      include: {
        modules: {
          include: { lessons: true, assignments: true }
        },
        instructor: true
      }
    });
    if (!course) return res.status(404).json({ error: 'Course not found' });
    res.json(course);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch course' });
  }
});

// Create a new course (Teacher/Admin only - auth middleware needed)
router.post('/', async (req: Request, res: Response) => {
  try {
    const { title, description, instructorId, thumbnailUrl } = req.body;
    const course = await prisma.course.create({
      data: {
        title,
        description,
        thumbnailUrl,
        instructorId
      }
    });
    res.status(201).json(course);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create course' });
  }
});

export default router;
