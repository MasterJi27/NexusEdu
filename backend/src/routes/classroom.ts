import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole, isOwnerOrAdmin } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';
import { aiRateLimit } from '../middlewares/aiRateLimit';
import { groqChat } from '../services/aiService';
import { enqueueRagIndex, indexSource } from '../services/ragService.js';
import { notifySection } from '../services/notifications';
import { parsePagination } from '../lib/pagination.js';

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
  content: z.string().trim().max(20000).optional(),
});

const gradeSchema = z.object({
  grade: z.number().min(0).max(1000),
  feedback: z.string().trim().max(5000).optional(),
});

async function isSectionOwner(sectionId: string, user: AuthRequest['user']) {
  const section = await prisma.section.findUnique({ where: { id: sectionId } });
  return section && isOwnerOrAdmin(section.teacherId, user) ? section : null;
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
  aiRateLimit,
  validateBody(syllabusSchema),
  async (req: AuthRequest, res: Response): Promise<void> => {
    const { sectionId, title, syllabus } = req.body;
    try {
      const section = await isSectionOwner(sectionId, req.user);
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
              'important definitions or formulas (LaTeX where relevant), 3-5 revision questions per chapter, and — ' +
              'where a diagram helps — a text diagram in a fenced code block using box-drawing characters ' +
              '(┌──┐ ├──┤ └──┘ and arrows →) showing flows, processes, cycles or hierarchies. ' +
              'Use clear English, headings (##), bullets and bold for key terms. Be thorough but concise — every chapter covered.',
          },
          { role: 'user', content: `Syllabus document:\n\n${syllabus}` },
        ],
        temperature: 0.3,
        maxTokens: 4000,
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

      // Ground the AI tutor / chat in this syllabus via queue, fallback to direct.
      void enqueueRagIndex({
        userId: req.user!.id,
        sourceType: 'syllabus',
        sourceId: note.id,
        title: note.title,
        content: note.content,
        gradeLevel: section.gradeLevel,
        subject: section.subject || 'General',
      }).then((enqueued) => { if (!enqueued) void indexSource({ userId: req.user!.id, sourceType: 'syllabus', sourceId: note.id, title: note.title, content: note.content, gradeLevel: section.gradeLevel, subject: section.subject || 'General' }); });

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
      const {limit,cursor}=parsePagination(req.query,20);
      const tasks = await prisma.classTask.findMany({
        where: sectionId
          ? { sectionId, section: { teacherId: req.user!.id } }
          : { section: { teacherId: req.user!.id } },
        take: limit,
        skip: cursor ? 1 : 0,
        cursor: cursor ? {id: cursor} : undefined,
        orderBy: {createdAt:'desc'},
        include: {
          section: { select: { id: true, label: true } },
          submissions: { select: { status: true, studentId: true } },
        },
      });
      const items = tasks.map((t) => ({
          ...t,
          doneCount: t.submissions.filter((s) => s.status === 'done').length,
          submissionCount: t.submissions.length,
          submissions: undefined,
        }));
      const nextCursor = tasks.length === limit ? tasks[tasks.length - 1].id : null;
      res.json({items, nextCursor});
      return;
    }

    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: req.user!.id },
      select: { sectionId: true, section: { select: { label: true } } },
    });
    const ids = enrollments.map((e) => e.sectionId);
    if (ids.length === 0) {
      res.json({items: [], nextCursor: null});
      return;
    }
    const {limit,cursor}=parsePagination(req.query,20);
    const tasks = await prisma.classTask.findMany({
      where: sectionId ? { sectionId, section: { id: { in: ids } } } : { section: { id: { in: ids } } },
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? {id: cursor} : undefined,
      orderBy: {createdAt:'desc'},
      include: {
        section: { select: { id: true, label: true } },
        submissions: {
          where: { studentId: req.user!.id },
          select: { status: true, updatedAt: true, content: true, grade: true, feedback: true, gradedAt: true },
        },
      },
    });
    const items = tasks.map((t) => ({
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
        myContent: t.submissions[0]?.content ?? null,
        myGrade: t.submissions[0]?.grade ?? null,
        myFeedback: t.submissions[0]?.feedback ?? null,
        gradedAt: t.submissions[0]?.gradedAt ?? null,
      }));
    const nextCursor = tasks.length === limit ? tasks[tasks.length - 1].id : null;
    res.json({items, nextCursor});
  } catch (error: any) {
    if (error?.status === 400) {
      res.status(400).json({ error: error.message });
      return;
    }
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
      const section = await isSectionOwner(sectionId, req.user);
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
    const { status, content } = req.body;
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
        create: { taskId, studentId: req.user!.id, status, content },
        // A resubmission clears any earlier grade — it's a new answer, not
        // the one that was graded.
        update: { status, content, grade: null, feedback: null, gradedAt: null },
      });
      res.json(submission);
    } catch (error) {
      console.error('Submit task error:', error);
      res.status(500).json({ error: 'Failed to update task.' });
    }
  },
);

/** Teacher: every student's submission for a task, for grading. */
router.get('/tasks/:id/submissions', requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const task = await prisma.classTask.findUnique({ where: { id: req.params.id as string } });
    if (!task) {
      res.status(404).json({ error: 'Task not found.' });
      return;
    }
    const section = await prisma.section.findUnique({ where: { id: task.sectionId } });
    if (!section || !isOwnerOrAdmin(section.teacherId, req.user)) {
      res.status(403).json({ error: 'You can only view submissions for your own tasks.' });
      return;
    }
    const {limit,cursor}=parsePagination(req.query,20);
    const submissions = await prisma.classTaskSubmission.findMany({
      where: { taskId: task.id },
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? {id: cursor} : undefined,
      orderBy: {submittedAt:'desc'},
      include: { student: { select: { id: true, name: true } } },
    });
    const nextCursor = submissions.length === limit ? submissions[submissions.length - 1].id : null;
    res.status(200).json({items: submissions, nextCursor});
  } catch (error: any) {
    if (error?.status === 400) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('List submissions error:', error);
    res.status(500).json({ error: 'Failed to fetch submissions.' });
  }
});

/** Teacher: grade a specific submission. */
router.post(
  '/submissions/:id/grade',
  requireRole('teacher', 'admin'),
  validateBody(gradeSchema),
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const submission = await prisma.classTaskSubmission.findUnique({
        where: { id: req.params.id as string },
        include: { task: { select: { sectionId: true, points: true } } },
      });
      if (!submission) {
        res.status(404).json({ error: 'Submission not found.' });
        return;
      }
      const section = await prisma.section.findUnique({ where: { id: submission.task.sectionId } });
      if (!section || !isOwnerOrAdmin(section.teacherId, req.user)) {
        res.status(403).json({ error: 'You can only grade submissions for your own sections.' });
        return;
      }
      if (req.body.grade > submission.task.points && submission.task.points > 0) {
        res.status(400).json({ error: `Grade cannot exceed the task's ${submission.task.points} points.` });
        return;
      }
      const graded = await prisma.classTaskSubmission.update({
        where: { id: submission.id },
        data: { grade: req.body.grade, feedback: req.body.feedback, gradedAt: new Date() },
      });
      await prisma.notification.create({
        data: {
          userId: submission.studentId,
          type: 'class_task',
          title: 'Assignment graded',
          body: `You scored ${req.body.grade}${submission.task.points ? `/${submission.task.points}` : ''}.`,
          link: '/classroom',
        },
      });
      res.status(200).json(graded);
    } catch (error) {
      console.error('Grade submission error:', error);
      res.status(500).json({ error: 'Failed to grade submission.' });
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

/**
 * Teacher home aggregate: everything the teacher landing screen shows in one
 * round trip — counts, live-now status and the most recent sections/live
 * classes. Kept flat and cheap (parallel queries, no nested fan-outs).
 */
router.get('/teacher/home', requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const teacherId = req.user!.id;
    const [sectionCount, noteCount, unreadCount, liveNow, recentSections, recentLive, teacher] =
      await Promise.all([
        prisma.section.count({ where: { teacherId } }),
        prisma.teacherNote.count({ where: { teacherId } }),
        prisma.notification.count({ where: { userId: teacherId, readAt: null } }),
        prisma.liveSession.findFirst({
          where: { teacherId, endedAt: null },
          include: { section: { select: { label: true } } },
          orderBy: { startedAt: 'desc' },
        }),
        prisma.section.findMany({
          where: { teacherId },
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: { _count: { select: { enrollments: true } } },
        }),
        prisma.liveSession.findMany({
          where: { teacherId },
          orderBy: { startedAt: 'desc' },
          take: 5,
          include: { section: { select: { label: true } } },
        }),
        prisma.user.findUnique({
          where: { id: teacherId },
          select: { name: true, organizationName: true, orgLogoUrl: true, accentColor: true },
        }),
      ]);
    const studentCount = recentSections.reduce((sum, s) => sum + s._count.enrollments, 0);
    res.status(200).json({
      teacherName: teacher?.name ?? 'Teacher',
      organizationName: teacher?.organizationName ?? null,
      orgLogoUrl: teacher?.orgLogoUrl ?? null,
      accentColor: teacher?.accentColor ?? null,
      sectionCount,
      studentCount,
      noteCount,
      unreadCount,
      liveNow: liveNow
        ? {
            id: liveNow.id,
            title: liveNow.title,
            sectionLabel: liveNow.section.label,
            startedAt: liveNow.startedAt,
            recordingAllowed: liveNow.recordingAllowed,
          }
        : null,
      recentSections: recentSections.map((s) => ({
        id: s.id,
        label: s.label,
        gradeLevel: s.gradeLevel,
        subject: s.subject,
        studentCount: s._count.enrollments,
      })),
      recentLive: recentLive.map((l) => ({
        id: l.id,
        title: l.title,
        sectionLabel: l.section.label,
        startedAt: l.startedAt,
        endedAt: l.endedAt,
      })),
    });
  } catch (error) {
    console.error('Teacher home error:', error);
    res.status(500).json({ error: 'Failed to load teacher home.' });
  }
});

export default router;
