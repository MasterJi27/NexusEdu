// TODO: migrate PUT /profile org fields to Organization model, gate by role
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
  // Reject non-images at the gate — the multipart Content-Type is
  // client-supplied and must never be the only check.
  fileFilter: (_req: any, file: any, cb: any) => {
    if (file?.mimetype?.startsWith('image/')) {
      cb(null, true);
    } else {
      const err: any = new Error('Only image files are allowed.');
      err.status = 400;
      cb(err);
    }
  },
});

// Magic-byte sniff: verifies the bytes are actually a raster image no matter
// what the client claimed, so the public avatar/logo URLs can't be used to
// host arbitrary content on the storage account.
function isRasterImage(buf: Buffer): boolean {
  if (buf.length < 12) return false;
  if (buf[0] === 0xff && buf[1] === 0xd8) return true; // JPEG
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return true; // PNG
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) return true; // GIF
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46) return true; // RIFF (WebP)
  return false;
}

// Replacing an avatar/logo would previously orphan the old blob forever.
// Best-effort delete of the previous image before uploading the new one.
async function deleteOldBlob(container: any, url: string | null | undefined): Promise<void> {
  if (!url) return;
  const name = url.split('/').pop();
  if (!name) return;
  try {
    await container.deleteBlob(decodeURIComponent(name));
  } catch {
    // Already gone, or the container predates uploads — never fail the upload.
  }
}

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
  studentId: true,
  organizationName: true, orgLogoUrl: true, accentColor: true,
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

// Account role is fixed at signup. A brand-new account (never logged in,
// lastLoginAt null) may still pick its role once — that covers the old
// signup-then-promote flow from previous app versions. After the first login
// the role is permanent: switching requires a new account.
const selfServiceRoles = ['student', 'teacher', 'parent'] as const;

const updateProfileSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  currentPassword: z.string().optional(),
  newPassword: z.string().min(6).max(200).optional(),
  gradeLevel: z.string().trim().max(100).optional(),
  schoolBoard: z.string().trim().max(50).optional(),
  weakSubjects: z.array(z.string().trim().max(50)).max(20).optional(),
  strongSubjects: z.array(z.string().trim().max(50)).max(20).optional(),
  role: z.enum(selfServiceRoles).optional(),
  studentId: z.string().trim().max(40).optional(),
  organizationName: z.string().trim().max(100).optional(),
  accentColor: z.string().trim().max(9).optional(),
});

router.put('/profile', authenticate, validateBody(updateProfileSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { name, currentPassword, newPassword, gradeLevel, schoolBoard, weakSubjects, strongSubjects, role, studentId, organizationName, accentColor } = req.body;
    const data: {
      name?: string; password?: string; gradeLevel?: string; schoolBoard?: string;
      weakSubjects?: string[]; strongSubjects?: string[]; role?: string;
      studentId?: string; organizationName?: string; accentColor?: string;
    } = {};

    if (name) data.name = name;
    if (gradeLevel !== undefined) data.gradeLevel = gradeLevel;
    if (schoolBoard !== undefined) data.schoolBoard = schoolBoard;
    if (weakSubjects !== undefined) data.weakSubjects = weakSubjects;
    if (strongSubjects !== undefined) data.strongSubjects = strongSubjects;
    if (role !== undefined) data.role = role;
    if (studentId !== undefined) data.studentId = studentId || null;
    if (organizationName !== undefined) data.organizationName = organizationName;
    if (accentColor !== undefined) data.accentColor = accentColor;

    if (newPassword || role !== undefined) {
      const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
      if (!user || (newPassword && !user.password)) {
        res.status(400).json({ error: 'Password change is not available for this account.' });
        return;
      }
      if (role !== undefined && role !== user.role) {
        // Role is permanent after first login; only fresh, never-logged-in
        // accounts (old signup flow) may still claim one.
        if (user.lastLoginAt !== null) {
          res.status(403).json({
            error: 'Account type is fixed after your first sign-in. Sign out and create a new account for a different role.',
          });
          return;
        }
        data.role = role;
      }
      if (newPassword) {
        if (!currentPassword || !(await bcrypt.compare(currentPassword, user.password!))) {
          res.status(401).json({ error: 'Current password is incorrect.' });
          return;
        }
        data.password = await bcrypt.hash(newPassword, 10);
        // A compromised password means every other device must re-authenticate.
        // Mirrors the reset flow (controllers/auth.ts); the current session —
        // already holding a valid token — is deliberately kept.
        await prisma.deviceSession.updateMany({
          where: { userId: req.user!.id, revokedAt: null, id: { not: req.user!.sessionId } },
          data: { revokedAt: new Date() },
        });
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
  } catch (error: any) {
    if (error?.code === 'P2002' && error?.meta?.target?.includes('studentId')) {
      res.status(409).json({ error: 'This admission/student ID is already in use by another account.' });
      return;
    }
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
    if (!isRasterImage(file.buffer)) {
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

    const existing = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: { photoUrl: true },
    });
    await deleteOldBlob(container, existing?.photoUrl);

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

// Upload / change the organization logo (school/college/institute branding).
// Mirrors the avatar route but writes to its own container so blobs stay
// grouped per purpose.
router.post('/org-logo', authenticate, upload.single('logo'), async (req: AuthRequest, res: Response): Promise<void> => {
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
    if (!isRasterImage(file.buffer)) {
      res.status(400).json({ error: 'Only image files are allowed.' });
      return;
    }

    const conn = process.env.AZURE_STORAGE_CONNECTION_STRING;
    if (!conn) {
      res.status(503).json({ error: 'Image upload is not configured on this server.' });
      return;
    }

    const blobService = BlobServiceClient.fromConnectionString(conn);
    const container = blobService.getContainerClient('org-logos');
    await container.createIfNotExists({ access: 'blob' });

    const existing = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: { orgLogoUrl: true },
    });
    await deleteOldBlob(container, existing?.orgLogoUrl);

    const ext = (file.originalname?.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '');
    const blobName = `${req.user!.id}-${Date.now()}.${ext}`;
    const blockBlob = container.getBlockBlobClient(blobName);
    await blockBlob.uploadData(file.buffer, {
      blobHTTPHeaders: { blobContentType: file.mimetype },
    });

    const updated = await prisma.user.update({
      where: { id: req.user!.id },
      data: { orgLogoUrl: blockBlob.url },
      select: profileSelect,
    });

    res.status(200).json(updated);
  } catch (error) {
    console.error('Org logo upload error:', error);
    res.status(500).json({ error: 'Failed to upload org logo.' });
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
