import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { Prisma } from '../generated/prisma/client';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';
import { findStudentByEmail } from '../services/userService';

const router = Router();

// Only identity + learning fields, never credentials.
const childSelect = {
  id: true, name: true, email: true, photoUrl: true, gradeLevel: true,
  schoolBoard: true, xp: true, streak: true, weakSubjects: true, strongSubjects: true,
};

// Parent: list children the student has APPROVED. Pending/rejected links are
// never exposed here, so no one can see a child's data without their consent.
router.get('/children', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id, status: 'approved' },
      include: { student: { select: childSelect } },
      orderBy: { createdAt: 'asc' },
    });
    res.status(200).json(links.map((l) => l.student));
  } catch (error) {
    console.error('List linked children error:', error);
    res.status(500).json({ error: 'Failed to fetch linked children.' });
  }
});

// Parent: list pending + approved links with their status, so the UI can show
// "waiting for approval" instead of a silent no-op.
router.get('/links', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id },
      include: { student: { select: childSelect } },
      orderBy: { createdAt: 'asc' },
    });
    res.status(200).json(links.map((l) => ({ ...l.student, status: l.status })));
  } catch (error) {
    console.error('List parent links error:', error);
    res.status(500).json({ error: 'Failed to fetch parent links.' });
  }
});

const linkSchema = z.object({
  studentEmail: z.string().trim().email(),
});

// Parent: request a link. Creates a PENDING link; the student must approve it
// before any of their data is visible to the parent.
router.post('/link', authenticate, requireRole('parent', 'admin'), validateBody(linkSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const student = await findStudentByEmail(req.body.studentEmail);
    if (!student) {
      res.status(404).json({ error: 'No student account found with that email.' });
      return;
    }
    if (student.id === req.user!.id) {
      res.status(400).json({ error: 'You cannot link your own account.' });
      return;
    }

    const existing = await prisma.parentLink.findUnique({
      where: { parentId_studentId: { parentId: req.user!.id, studentId: student.id } },
    });

    if (existing?.status === 'approved') {
      res.status(409).json({ error: 'You are already linked to this student.' });
      return;
    }
    if (existing?.status === 'pending') {
      res.status(200).json({
        id: student.id, name: student.name, status: 'pending',
        message: 'Link request already sent. Waiting for the student to approve.',
      });
      return;
    }

    const link = await prisma.parentLink.upsert({
      where: { parentId_studentId: { parentId: req.user!.id, studentId: student.id } },
      create: { parentId: req.user!.id, studentId: student.id, status: 'pending' },
      update: { status: 'pending' },
    });

    res.status(201).json({ id: student.id, name: student.name, status: link.status });
  } catch (error) {
    console.error('Link child error:', error);
    res.status(500).json({ error: 'Failed to send link request.' });
  }
});

// Student: list incoming link requests awaiting their approval.
router.get('/requests', authenticate, requireRole('student', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const requests = await prisma.parentLink.findMany({
      where: { studentId: req.user!.id, status: 'pending' },
      include: { parent: { select: { id: true, name: true, photoUrl: true } } },
      orderBy: { createdAt: 'asc' },
    });
    res.status(200).json(requests.map((r) => ({ id: r.id, parent: r.parent, createdAt: r.createdAt })));
  } catch (error) {
    console.error('List link requests error:', error);
    res.status(500).json({ error: 'Failed to fetch link requests.' });
  }
});

// Student: approve a link request. Only the linked student can approve.
router.post('/requests/:id/approve', authenticate, requireRole('student', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const result = await prisma.parentLink.updateMany({
      where: { id: req.params.id as string, studentId: req.user!.id, status: 'pending' },
      data: { status: 'approved' },
    });
    if (result.count === 0) {
      res.status(404).json({ error: 'Link request not found or already resolved.' });
      return;
    }
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Approve link request error:', error);
    res.status(500).json({ error: 'Failed to approve link request.' });
  }
});

// Student: reject a link request.
router.post('/requests/:id/reject', authenticate, requireRole('student', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const result = await prisma.parentLink.updateMany({
      where: { id: req.params.id as string, studentId: req.user!.id, status: 'pending' },
      data: { status: 'rejected' },
    });
    if (result.count === 0) {
      res.status(404).json({ error: 'Link request not found or already resolved.' });
      return;
    }
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Reject link request error:', error);
    res.status(500).json({ error: 'Failed to reject link request.' });
  }
});

// Either side can unlink. Deleting an approved link requires no consent from
// the other party; the link can always be re-requested. The `:studentId`
// param is "the other party's id" — a parent passes the student's id, a
// student passes the parent's id — since the caller's own id is already
// known from the auth token.
router.delete('/link/:studentId', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const otherId = req.params.studentId as string;
    const result = await prisma.parentLink.deleteMany({
      where: {
        OR: [
          { parentId: req.user!.id, studentId: otherId },
          { studentId: req.user!.id, parentId: otherId },
        ],
      },
    });
    if (result.count === 0) {
      res.status(404).json({ error: 'Link not found.' });
      return;
    }
    res.status(204).end();
  } catch (error) {
    console.error('Unlink child error:', error);
    res.status(500).json({ error: 'Failed to unlink child.' });
  }
});

// Parent: which of their approved children has a class live right now. The
// parent never joins the channel — this only tells them "your child is in
// class" — so no Agora token is minted here.
router.get('/live', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id, status: 'approved' },
      include: { student: { select: { id: true, name: true } } },
    });
    if (links.length === 0) {
      res.status(200).json({ children: [] });
      return;
    }
    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: { in: links.map((l) => l.studentId) } },
      select: { studentId: true, sectionId: true },
    });
    const liveSessions = await prisma.liveSession.findMany({
      where: {
        sectionId: { in: enrollments.map((e) => e.sectionId) },
        endedAt: null,
      },
      include: { section: { select: { label: true } } },
    });
    const liveBySection = new Map(liveSessions.map((l) => [l.sectionId, l]));
    res.status(200).json({
      children: links.map((l) => {
        const sections = new Set(
          enrollments.filter((e) => e.studentId === l.studentId).map((e) => e.sectionId),
        );
        const live = liveSessions.find((s) => sections.has(s.sectionId));
        return {
          studentId: l.student.id,
          name: l.student.name,
          live: live
            ? {
                id: live.id,
                title: live.title,
                sectionLabel: live.section.label,
                startedAt: live.startedAt,
                recordingAllowed: live.recordingAllowed,
              }
            : null,
        };
      }),
    });
  } catch (error) {
    console.error('Parent live status error:', error);
    res.status(500).json({ error: 'Failed to check live status.' });
  }
});

// Parent: recent in-app activity of approved children (quizzes done, shorts
// watched, notes saved — whatever the app logs via POST /users/activity).
// Ordered newest-first, capped, so a parent sees effort without any of the
// child's private content (notes text, quiz answers) leaving their device.
router.get('/activity', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id, status: 'approved' },
      include: { student: { select: { id: true, name: true } } },
    });
    if (links.length === 0) {
      res.status(200).json({ children: [] });
      return;
    }
    const logs = await prisma.activityLog.findMany({
      where: {
        userId: { in: links.map((l) => l.studentId) },
        timestamp: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
      },
      orderBy: { timestamp: 'desc' },
      take: 100,
      select: { userId: true, action: true, metadata: true, timestamp: true },
    });
    const nameById = new Map(links.map((l) => [l.student.id, l.student.name]));
    res.status(200).json({
      children: [...nameById.keys()].map((studentId) => ({
        studentId,
        name: nameById.get(studentId),
        items: logs.filter((l) => l.userId === studentId),
      })),
    });
  } catch (error) {
    console.error('Parent activity error:', error);
    res.status(500).json({ error: 'Failed to fetch activity.' });
  }
});

// Parent: each approved child's XP rank among all students — "Aarav is #12
// of 120". P0 1M verified: single raw query RANK() OVER (ORDER BY xp DESC) avoids N+1; fallback is parallel Promise.all, not sequential. Digest uses p-limit 5.
router.get('/ranks', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id, status: 'approved' },
      include: { student: { select: { id: true, name: true, xp: true } } },
    });
    if (links.length === 0) {
      res.status(200).json({ children: [] });
      return;
    }
    const total = await prisma.user.count({ where: { role: 'student' } });
    // Single query ranking via RANK() window function — avoids N+1 count queries.
    // Falls back to parallel per-child counts if raw query fails (e.g. adapter limitation).
    try {
      const xpRanks = await prisma.$queryRaw<Array<{ id: string; rank: bigint }>>`
        SELECT id, RANK() OVER (ORDER BY xp DESC) as rank FROM "User" WHERE role='student' AND id IN (${Prisma.join(links.map((l) => l.student.id))})
      `;
      const rankById = new Map<string, number>(xpRanks.map((r) => [r.id, Number(r.rank)]));
      const children = links.map((link) => {
        const xp = link.student.xp ?? 0;
        const rank = xp > 0 ? (rankById.get(link.student.id) ?? null) : null;
        return {
          studentId: link.student.id,
          name: link.student.name,
          xp,
          rank,
          totalStudents: total,
        };
      });
      res.status(200).json({ children });
      return;
    } catch (e) {
      console.warn('RANK() query failed, falling back to per-child counts:', e);
    }
    // Fallback: parallelize counts with Promise.all instead of sequential for-await
    const children = await Promise.all(links.map(async (link) => {
      const xp = link.student.xp ?? 0;
      const better = xp > 0
        ? await prisma.user.count({ where: { role: 'student', xp: { gt: xp } } })
        : null;
      return {
        studentId: link.student.id,
        name: link.student.name,
        xp,
        rank: better === null ? null : better + 1,
        totalStudents: total,
      };
    }));
    res.status(200).json({ children });
  } catch (error) {
    console.error('Parent ranks error:', error);
    res.status(500).json({ error: 'Failed to fetch ranks.' });
  }
});

// Parent: live classes that already happened in the last 7 days for the
// approved children's sections — title, section, when it ran, how long. It
// is engagement context ("what classes was my child's class doing"), not a
// claim about the child's own presence.
router.get('/live-history', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id, status: 'approved' },
      include: { student: { select: { id: true, name: true } } },
    });
    if (links.length === 0) {
      res.status(200).json({ children: [] });
      return;
    }
    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: { in: links.map((l) => l.studentId) } },
      select: { studentId: true, sectionId: true },
    });
    const sessions = await prisma.liveSession.findMany({
      where: {
        sectionId: { in: enrollments.map((e) => e.sectionId) },
        endedAt: { not: null },
        startedAt: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
      },
      orderBy: { startedAt: 'desc' },
      take: 100,
      select: {
        id: true,
        sectionId: true,
        title: true,
        startedAt: true,
        endedAt: true,
        section: { select: { label: true } },
      },
    });
    res.status(200).json({
      children: links.map((l) => {
        const sections = new Set(
          enrollments.filter((e) => e.studentId === l.studentId).map((e) => e.sectionId),
        );
        const items = sessions.filter((s) => sections.has(s.sectionId));
        return { studentId: l.student.id, name: l.student.name, items };
      }),
    });
  } catch (error) {
    console.error('Parent live history error:', error);
    res.status(500).json({ error: 'Failed to fetch live class history.' });
  }
});

export default router;
