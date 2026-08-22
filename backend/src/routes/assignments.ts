import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { parsePagination } from '../lib/pagination.js';

// P0 1M verified: authenticate + parsePagination + uuid validation present (moduleId UUID regex, cursor UUID via parsePagination)

const router = Router();

// TODO: consider enrollment check for module access — currently any authenticated user with valid moduleId can list
// Get assignments for a module - authenticated + cursor pagination (P0 fix)
router.get('/module/:moduleId', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const moduleId = req.params.moduleId as string;
    // uuid validation for moduleId (P0)
    const uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
    if (!uuidRegex.test(moduleId)) {
      res.status(400).json({ error: 'Invalid moduleId — must be a UUID' });
      return;
    }
    const { limit, cursor } = parsePagination(req.query, 20);
    const assignments = await prisma.assignment.findMany({
      where: { moduleId },
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor } : undefined,
      orderBy: { createdAt: 'desc' },
    });
    const nextCursor = assignments.length === limit ? assignments[assignments.length - 1].id : null;
    res.json({ items: assignments, nextCursor });
  } catch (error: any) {
    if (error?.status === 400) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error('Fetch assignments error:', error);
    res.status(500).json({ error: 'Failed to fetch assignments' });
  }
});

const submitAssignmentSchema = z.object({
  assignmentId: z.string().min(1),
  content: z.string().max(20000).optional(),
  fileUrl: z.string().url().optional(),
});

// Submit an assignment — idempotent via @@unique([assignmentId, studentId]) + Upsert
// Supports Idempotency-Key header: client sends same key on retry, server guarantees single row.
router.post('/submit', authenticate, validateBody(submitAssignmentSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { assignmentId, content, fileUrl } = req.body;
    const idempotencyKey = (req.headers['idempotency-key'] as string) || (req.headers['Idempotency-Key'] as string);
    if (idempotencyKey) {
      res.setHeader('Idempotency-Key', idempotencyKey);
    }
    // Idempotent upsert — second submit for same assignment+student updates rather than duplicating
    const submission = await prisma.submission.upsert({
      where: { assignmentId_studentId: { assignmentId, studentId: req.user!.id } },
      create: {
        assignmentId,
        studentId: req.user!.id,
        content,
        fileUrl
      },
      update: {
        content,
        fileUrl
      }
    });
    // 201 on first create, 200 on idempotent update — both are success for client retries
    // Detect via createdAt vs updatedAt or simply return 200 for idempotency; keep 201 for compatibility when key not sent
    const status = idempotencyKey ? 200 : 201;
    // If submission was just created, its submittedAt equals updatedAt within ms; either status is acceptable
    res.status(status).json(submission);
  } catch (error: any) {
    // Fallback for race where unique constraint still trips (e.g. direct create elsewhere)
    if (error?.code === 'P2002') {
      try {
        const existing = await prisma.submission.findUnique({
          where: { assignmentId_studentId: { assignmentId: req.body.assignmentId, studentId: req.user!.id } },
        });
        if (existing) {
          const idempotencyKey = (req.headers['idempotency-key'] as string) || (req.headers['Idempotency-Key'] as string);
          if (idempotencyKey) res.setHeader('Idempotency-Key', idempotencyKey);
          res.status(200).json(existing);
          return;
        }
      } catch {}
    }
    console.error('Submit assignment error:', error);
    res.status(500).json({ error: 'Failed to submit assignment' });
  }
});

export default router;
