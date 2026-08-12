import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
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
// the other party; the link can always be re-requested.
router.delete('/link/:studentId', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.parentLink.deleteMany({
      where: {
        studentId: req.params.studentId as string,
        parentId: req.user!.id,
      },
    });
    res.status(204).end();
  } catch (error) {
    console.error('Unlink child error:', error);
    res.status(500).json({ error: 'Failed to unlink child.' });
  }
});

export default router;
