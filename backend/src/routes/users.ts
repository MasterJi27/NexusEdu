import express, { Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { BlobServiceClient } from '@azure/storage-blob';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { env } from '../lib/env';

// multer has no bundled types; require avoids adding a devDependency.
const multer = require('multer');
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
});

const router = express.Router();

// Authenticated: this returns other students' names and photos, so it must not
// be readable by anonymous callers. Only students who have actually scored are
// listed — a wall of zero-XP real names is both useless and needlessly
// exposing for accounts that never opted into competing.
router.get('/leaderboard', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const topUsers = await prisma.user.findMany({
      where: { role: 'student', xp: { gt: 0 } },
      orderBy: { xp: 'desc' },
      take: 50,
      select: {
        id: true,
        name: true,
        photoUrl: true,
        xp: true,
        streak: true,
      },
    });
    res.status(200).json(topUsers);
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

const profileSelect = {
  id: true, name: true, email: true, role: true, photoUrl: true,
  xp: true, streak: true, createdAt: true,
  gradeLevel: true, schoolBoard: true, weakSubjects: true, strongSubjects: true,
};

router.get('/profile', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: profileSelect,
    });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    res.status(200).json(user);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// Self-service role switch: a brand-new account may declare itself
// student/teacher/parent (e.g. from the onboarding role picker). 'admin' is
// intentionally excluded — that can't be self-granted. The switch is only
// allowed within 24h of signup, so a signed-up student can't later flip
// themselves into teacher (teacher notes, attendance controls) at will.
const selfServiceRoles = ['student', 'teacher', 'parent'] as const;
const ROLE_SWITCH_GRACE_MS = 24 * 60 * 60 * 1000;

const updateProfileSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  currentPassword: z.string().optional(),
  newPassword: z.string().min(6).max(200).optional(),
  gradeLevel: z.string().trim().max(20).optional(),
  schoolBoard: z.string().trim().max(50).optional(),
  weakSubjects: z.array(z.string().trim().max(50)).max(20).optional(),
  strongSubjects: z.array(z.string().trim().max(50)).max(20).optional(),
  role: z.enum(selfServiceRoles).optional(),
});

router.put('/profile', authenticate, validateBody(updateProfileSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { name, currentPassword, newPassword, gradeLevel, schoolBoard, weakSubjects, strongSubjects, role } = req.body;
    const data: {
      name?: string; password?: string; gradeLevel?: string; schoolBoard?: string;
      weakSubjects?: string[]; strongSubjects?: string[]; role?: string;
    } = {};

    if (name) data.name = name;
    if (gradeLevel !== undefined) data.gradeLevel = gradeLevel;
    if (schoolBoard !== undefined) data.schoolBoard = schoolBoard;
    if (weakSubjects !== undefined) data.weakSubjects = weakSubjects;
    if (strongSubjects !== undefined) data.strongSubjects = strongSubjects;
    if (role !== undefined) data.role = role;

    if (newPassword || role !== undefined) {
      const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
      if (!user || (newPassword && !user.password)) {
        res.status(400).json({ error: 'Password change is not available for this account.' });
        return;
      }
      if (newPassword) {
        if (!currentPassword || !(await bcrypt.compare(currentPassword, user.password!))) {
          res.status(401).json({ error: 'Current password is incorrect.' });
          return;
        }
        data.password = await bcrypt.hash(newPassword, 10);
      }
      if (role !== undefined) {
        const isNewAccount = Date.now() - user.createdAt.getTime() < ROLE_SWITCH_GRACE_MS;
        if (!isNewAccount && user.role !== role) {
          res.status(403).json({ error: 'Account role can only be chosen within 24 hours of signing up.' });
          return;
        }
        data.role = role;
      }
    }

    const updated = await prisma.user.update({
      where: { id: req.user!.id },
      data,
      select: profileSelect,
    });

    // The JWT carries the role as a claim, so a role change must reissue the
    // token - otherwise role-gated routes keep seeing the pre-change role
    // until the user logs out and back in.
    const token = role !== undefined
      ? jwt.sign(
          {
            id: updated.id,
            email: updated.email,
            role: updated.role,
            sid: req.user!.sessionId,
          },
          env.JWT_SECRET,
          { expiresIn: '30d' },
        )
      : undefined;

    res.status(200).json({ ...updated, ...(token ? { token } : {}) });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// Upload / change profile avatar. Stores the image in Azure Blob Storage and
// saves the resulting URL on the user.
router.post('/avatar', authenticate, upload.single('avatar'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const file = (req as any).file;
    if (!file) {
      res.status(400).json({ error: 'No image provided.' });
      return;
    }
    if (!file.mimetype?.startsWith('image/')) {
      res.status(400).json({ error: 'Only image files are allowed.' });
      return;
    }

    const conn = process.env.AZURE_STORAGE_CONNECTION_STRING;
    if (!conn) {
      res.status(503).json({ error: 'Image upload is not configured on this server.' });
      return;
    }

    const blobService = BlobServiceClient.fromConnectionString(conn);
    const container = blobService.getContainerClient('avatars');
    await container.createIfNotExists({ access: 'blob' });

    const ext = (file.originalname?.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '');
    const blobName = `${req.user!.id}-${Date.now()}.${ext}`;
    const blockBlob = container.getBlockBlobClient(blobName);
    await blockBlob.uploadData(file.buffer, {
      blobHTTPHeaders: { blobContentType: file.mimetype },
    });

    const updated = await prisma.user.update({
      where: { id: req.user!.id },
      data: { photoUrl: blockBlob.url },
      select: profileSelect,
    });

    res.status(200).json(updated);
  } catch (error) {
    console.error('Avatar upload error:', error);
    res.status(500).json({ error: 'Failed to upload avatar.' });
  }
});

// The app's local gamification (streak, XP) is the source of truth for a
// student's own effort; this endpoint lets the client push it up so the
// leaderboard and parent dashboards see real numbers. Absolute set, not a
// delta — the client syncs its full current value, and nothing else on the
// server mutates xp/streak today.
const progressSchema = z.object({
  xp: z.number().int().min(0).max(10_000_000).optional(),
  streak: z.number().int().min(0).max(3650).optional(),
});

router.put('/progress', authenticate, validateBody(progressSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.user.update({
      where: { id: req.user!.id },
      data: req.body,
      select: { id: true, xp: true, streak: true },
    });
    res.status(200).json(updated);
  } catch (error) {
    console.error('Update progress error:', error);
    res.status(500).json({ error: 'Failed to update progress.' });
  }
});

// Append-only audit trail of what a student did in the app (note saved,
// quiz completed, short watched). Nothing reads it yet except future parent
// reporting; keeping it on every action now means history exists before
// anyone asks for it.
const activitySchema = z.object({
  action: z.string().trim().min(1).max(100),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

router.post('/activity', authenticate, validateBody(activitySchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.activityLog.create({
      data: {
        userId: req.user!.id,
        action: req.body.action,
        metadata: req.body.metadata ?? undefined,
      },
    });
    res.status(201).json({ status: 'ok' });
  } catch (error) {
    console.error('Log activity error:', error);
    res.status(500).json({ error: 'Failed to log activity.' });
  }
});

export default router;
