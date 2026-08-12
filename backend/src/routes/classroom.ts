import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole, isOwnerOrAdmin } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';
import { groqChat } from '../services/aiService';
import { indexSource } from '../services/ragService';

/**
 * Google-Classroom-style classwork for Section-based classrooms:
 *
 * - Teachers post a syllabus (raw text) for a section; the AI converts it
 *   into structured, student-ready study notes which land in Class Notes and
 *   the RAG index, and every enrolled student gets an in-app notification.
 * - Teachers assign tasks to a section; students see them in the Classroom
 *   tab and mark them done. Submissions are one per task per student.
 * - Notifications are the in-app stream (no push infra yet): teacher_note /
 *   class_task entries, read/unread badge included.
 */
const router = Router();
router.use(authenticate);

const syllabusSchema = z.object({
  sectionId: z.string().min(1),
  title: z.string().trim().min(1).max(200),
  syllabus: z.string().trim().min(10).max(50000),
});

const taskSchema = z.object({
  sectionId: z.string().min(1),
  title: z.string().trim().min(1).max(200),
  description: z.string().trim().max(5000).optional(),
  dueDate: z.string().datetime().optional().nullable(),
  points: z.number().int().min(0).max(1000).optional(),
});

const submissionSchema = z.object({
  status: z.enum(['done', 'pending']),
});

async function isSectionOwner(sectionId: string, teacherId: string) {
  const section = await prisma.section.findUnique({ where: { id: sectionId } });
  return section && section.teacherId === teacherId ? section : null;
}

async function notifySection(
  section: { id: string; label: string },
  type: string,
  title: string,
  body: string,
  link: string,
) {
  const enrollments = await prisma.enrollment.findMany({
    where: { sectionId: section.id },
    select: { studentId: true },
  });
  if (enrollments.length === 0) return;
  await prisma.notification.createMany({
    data: enrollments.map((e) => ({
      userId: e.studentId,
      type,
      title,
      body,
      link,
    })),
  });
}

/**
 * Teacher posts a syllabus document. The AI turns it into structured notes
 * (headings per chapter, key points, formulas/definitions to memorise) and
 * saves them as a published TeacherNote for the section's grade, indexed for
 * RAG. Students of the section get a notification.
 */
router.post(
  '/syllabus',
  requireRole('teacher', 'admin'),
  validateBody(syllabusSchema),
  async (req: AuthRequest, res: Response): Promise<void> => {
    const { sectionId, title, syllabus } = req.body;
    try {
      const section = await isSectionOwner(sectionId, req.user!.id);
      if (!section) {
        res.status(403).json({ error: 'You can only post to your own sections.' });
        return;
      }

      const data = await groqChat({
        messages: [
          {
            role: 'system',
            content:
              'You convert a school syllabus document into structured study notes for an Indian student (CBSE/ICSE/JEE/NEET). ' +
              'Output clean Markdown with a chapter-by-chapter breakdown: a short description of each unit, key topics, ' +
              'important definitions or formulas where relevant, and 3-5 revision questions per chapter. ' +
              'Use clear English, headings (##), bullets and bold for key terms. Be thorough but concise — every chapter covered.',
          },
          { role: 'user', content: `Syllabus document:\n\n${syllabus}` },
        ],
        temperature: 0.3,
        maxTokens: 3000,
        feature: 'custom',
        userId: req.user!.id,
      });

      const content = data.choices[0]?.message?.content?.trim();
      if (!content) {
        res.status(502).json({ error: 'AI could not convert this syllabus. Please try again.' });
        return;
      }

      const note = await prisma.teacherNote.create({
        data: {
          title: `${title}`,
          content,
          gradeLevel: section.gradeLevel,
          subject: section.subject || 'General',
          topic: 'Syllabus notes',
          isPublished: true,
          teacherId: req.user!.id,
        },
        select: {
          id: true,
          title: true,
          content: true,
          gradeLevel: true,
          subject: true,
          topic: true,
          createdAt: true,
          teacher: { select: { id: true, name: true } },
        },
      });

      // Ground the AI tutor / chat in this syllabus for everyone at that grade.
      void indexSource({
        userId: req.user!.id,
        sourceType: 'syllabus',
        sourceId: note.id,
        title: note.title,
        content: note.content,
        gradeLevel: section.gradeLevel,
        subject: section.subject || 'General',
      });

      await notifySection(
        section,
        'teacher_note',
        `New syllabus notes: ${title}`,
        `${section.label} · AI notes for the uploaded syllabus are ready in Class Notes.`,
        '/notes',
      );

      res.status(201).json({ note });
    } catch (error: any) {
      console.error('Syllabus conversion error:', error);
      res.status(error.statusCode || 500).json({
        error: 'Failed to convert syllabus',
        ...(error.quota ? { quota: error.quota } : {}),
      });
    }
  },
);

/** Tasks for a section. Teachers see every submission; students see their own. */
router.get('/tasks', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const sectionId = req.query.sectionId as string | undefined;
    const isTeacher = req.user!.role === 'teacher' || req.user!.role === 'admin';

    if (isTeacher) {
      const tasks = await prisma.classTask.findMany({
        where: sectionId ? { sectionId } : { section: { teacherId: req.user!.id } },
        orderBy: { createdAt: 'desc' },
        include: {
          section: { select: { id: true, label: true } },
          submissions: { select: { status: true, studentId: true } },
        },
      });
      res.json(
        tasks.map((t) => ({
          ...t,
          doneCount: t.submissions.filter((s) => s.status === 'done').length,
          submissionCount: t.submissions.length,
          submissions: undefined,
        })),
      );
      return;
    }

    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: req.user!.id },
      select: { sectionId: true, section: { select: { label: true } } },
    });
    const ids = enrollments.map((e) => e.sectionId);
    if (ids.length === 0) {
      res.json([]);
      return;
    }
    const tasks = await prisma.classTask.findMany({
      where: sectionId ? { sectionId, section: { id: { in: ids } } } : { section: { id: { in: ids } } },
      orderBy: { createdAt: 'desc' },
      include: {
        section: { select: { id: true, label: true } },
        submissions: {
          where: { studentId: req.user!.id },
          select: { status: true, updatedAt: true },
        },
      },
    });
    res.json(
      tasks.map((t) => ({
        id: t.id,
        sectionId: t.sectionId,
        section: t.section,
        title: t.title,
        description: t.description,
        dueDate: t.dueDate,
        points: t.points,
        createdAt: t.createdAt,
        myStatus: t.submissions[0]?.status ?? 'pending',
        submittedAt: t.submissions[0]?.updatedAt ?? null,
      })),
    );
  } catch (error) {
    console.error('List tasks error:', error);
    res.status(500).json({ error: 'Failed to fetch tasks.' });
  }
});

router.post(
  '/tasks',
  requireRole('teacher', 'admin'),
  validateBody(taskSchema),
  async (req: AuthRequest, res: Response): Promise<void> => {
    const { sectionId, title, description, dueDate, points } = req.body;
    try {
      const section = await isSectionOwner(sectionId, req.user!.id);
      if (!section) {
        res.status(403).json({ error: 'You can only assign to your own sections.' });
        return;
      }
      const task = await prisma.classTask.create({
        data: {
          sectionId,
          title,
          description,
          dueDate: dueDate ? new Date(dueDate) : null,
          points: points ?? 0,
        },
        include: { section: { select: { label: true } } },
      });
      await notifySection(
        section,
        'class_task',
        `New task: ${title}`,
        `${section.label} · ${task.points} points${task.dueDate ? `, due ${task.dueDate.toLocaleDateString('en-IN')}` : ''}.`,
        '/classroom',
      );
      res.status(201).json(task);
    } catch (error) {
      console.error('Create task error:', error);
      res.status(500).json({ error: 'Failed to create task.' });
    }
  },
);

router.delete('/tasks/:id', requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const task = await prisma.classTask.findUnique({ where: { id: req.params.id as string } });
    if (!task) {
      res.status(404).json({ error: 'Task not found.' });
      return;
    }
    const section = await prisma.section.findUnique({ where: { id: task.sectionId } });
    if (!section || !isOwnerOrAdmin(section.teacherId, req.user)) {
      res.status(403).json({ error: 'You can only delete your own tasks.' });
      return;
    }
    await prisma.classTask.delete({ where: { id: task.id } });
    res.status(204).end();
  } catch (error) {
    console.error('Delete task error:', error);
    res.status(500).json({ error: 'Failed to delete task.' });
  }
});

/** Student flips their own submission status on a task (done / pending). */
router.post(
  '/tasks/:id/submit',
  validateBody(submissionSchema),
  async (req: AuthRequest, res: Response): Promise<void> => {
    const taskId = req.params.id as string;
    const { status } = req.body;
    try {
      const task = await prisma.classTask.findUnique({ where: { id: taskId } });
      if (!task) {
        res.status(404).json({ error: 'Task not found.' });
        return;
      }
      const enrollment = await prisma.enrollment.findUnique({
        where: { sectionId_studentId: { sectionId: task.sectionId, studentId: req.user!.id } },
      });
      if (!enrollment) {
        res.status(403).json({ error: 'You are not enrolled in this section.' });
        return;
      }
      const submission = await prisma.classTaskSubmission.upsert({
        where: { taskId_studentId: { taskId, studentId: req.user!.id } },
        create: { taskId, studentId: req.user!.id, status },
        update: { status },
      });
      res.json(submission);
    } catch (error) {
      console.error('Submit task error:', error);
      res.status(500).json({ error: 'Failed to update task.' });
    }
  },
);

/** In-app notification stream: unread first, optional unread badge count. */
router.get('/notifications', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const [items, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { userId: req.user!.id },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.notification.count({ where: { userId: req.user!.id, readAt: null } }),
    ]);
    res.json({ items, unreadCount });
  } catch (error) {
    console.error('List notifications error:', error);
    res.status(500).json({ error: 'Failed to fetch notifications.' });
  }
});

/** Mark one notification (or all when no id given) as read. */
router.post('/notifications/read', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = (req.body?.id as string) || undefined;
    if (id) {
      await prisma.notification.updateMany({
        where: { id, userId: req.user!.id },
        data: { readAt: new Date() },
      });
    } else {
      await prisma.notification.updateMany({
        where: { userId: req.user!.id, readAt: null },
        data: { readAt: new Date() },
      });
    }
    res.status(204).end();
  } catch (error) {
    console.error('Mark notifications read error:', error);
    res.status(500).json({ error: 'Failed to update notifications.' });
  }
});

export default router;
