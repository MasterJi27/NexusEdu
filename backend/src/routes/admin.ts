// TODO: add org stats endpoint — aggregate members/sections per Organization for admin dashboard
import { Router, Response } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { logActivity } from '../lib/logger';

/**
 * Institute management: shared by the Principal (admin), Institute Managers
 * (im) and HODs. Admins can do everything; IM/HOD are scoped by the
 * permissions a principal assigned (stored on User.imPermissions — null
 * means full scope, like an admin).
 */
const router = Router();
router.use(authenticate);

export const IM_PERMISSIONS = ['live_classes', 'manage_users', 'create_im'] as const;
export type ImPermission = (typeof IM_PERMISSIONS)[number];

const MANAGER_ROLES = ['admin', 'im', 'hod'] as const;

/** Role gate for the management surface: admin, im or hod. Permission
 *  checks apply to IMs only (their grants live on the user row, not in the
 *  JWT). Admins and HODs always pass. */
export async function requireManager(req: AuthRequest, res: Response, permission?: ImPermission): Promise<boolean> {
  const role = req.user!.role;
  if (!(MANAGER_ROLES as readonly string[]).includes(role)) {
    res.status(403).json({ error: 'This area is for Principal, IAM or HOD accounts.' });
    return false;
  }
  if (permission && role === 'im') {
    const account = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: { imPermissions: true },
    });
    const perms = account?.imPermissions as string[] | null | undefined;
    if (perms !== null && perms !== undefined && !perms.includes(permission)) {
      res.status(403).json({ error: 'Your assigned access does not include this module.' });
      return false;
    }
  }
  return true;
}

// Live classes across the whole institute: every open broadcast, with the
// teacher and section, so the Principal/IM/HOD can watch any class live.
router.get('/live-classes', async (req: AuthRequest, res: Response): Promise<void> => {
  if (!(await requireManager(req, res, 'live_classes'))) return;
  try {
    const lives = await prisma.liveSession.findMany({
      where: { endedAt: null },
      orderBy: { startedAt: 'desc' },
      select: {
        id: true,
        title: true,
        startedAt: true,
        recordingAllowed: true,
        teacher: { select: { id: true, name: true } },
        section: { select: { id: true, label: true } },
      },
    });
    res.status(200).json({ items: lives });
  } catch (error) {
    console.error('List institute live classes error:', error);
    res.status(500).json({ error: 'Failed to fetch live classes.' });
  }
});

const createImSchema = z.object({
  name: z.string().trim().min(1).max(120),
  email: z.string().trim().email().max(200),
  password: z.string().min(6).max(100),
  permissions: z.array(z.enum(IM_PERMISSIONS)).max(IM_PERMISSIONS.length).default([]),
});

// Teacher/Principal/IM creates an Institute Manager account. The creator
// hands the credentials to the new IM — they sign in from the IM persona.
router.post('/create-im', validateBody(createImSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  const role = req.user!.role;
  if (!['teacher', 'admin', 'im'].includes(role)) {
    res.status(403).json({ error: 'Only a Teacher or the Principal can create IAM accounts.' });
    return;
  }
  if (role === 'im' && !(await requireManager(req, res, 'create_im'))) return;
  try {
    const email = String(req.body.email).trim().toLowerCase();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      res.status(400).json({ error: 'An account already exists with this email.' });
      return;
    }
    const passwordHash = await bcrypt.hash(req.body.password, 10);
    const user = await prisma.user.create({
      data: {
        name: req.body.name,
        email,
        password: passwordHash,
        role: 'im',
        imPermissions: (req.body.permissions as ImPermission[]).length > 0
          ? req.body.permissions
          : null,
      },
      select: { id: true, name: true, email: true, role: true, imPermissions: true },
    });
    await logActivity(req.user!.id, 'IM_CREATED', { imId: user.id, imEmail: user.email });
    res.status(201).json({ user });
  } catch (error) {
    console.error('Create IM error:', error);
    res.status(500).json({ error: 'Failed to create the IAM account.' });
  }
});

// User directory for the management screen: searchable by name/email/student
// id, so the principal can find anyone and assign (or change) their role.
router.get('/users', async (req: AuthRequest, res: Response): Promise<void> => {
  if (!(await requireManager(req, res, 'manage_users'))) return;
  try {
    const q = String(req.query.q || '').trim();
    const users = await prisma.user.findMany({
      where: q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { email: { contains: q, mode: 'insensitive' } },
              { studentId: { contains: q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        studentId: true,
        gradeLevel: true,
        imPermissions: true,
      },
    });
    res.status(200).json({ items: users });
  } catch (error) {
    console.error('List users error:', error);
    res.status(500).json({ error: 'Failed to fetch users.' });
  }
});

const assignRoleSchema = z.object({
  role: z.enum(['teacher', 'hod', 'im', 'student', 'parent']),
  permissions: z.array(z.enum(IM_PERMISSIONS)).max(IM_PERMISSIONS.length).optional(),
});

// Principal (or an IM with manage_users): promote a teacher to HOD, make
// someone an IM with a specific access scope, or revert a management role.
// Admins themselves are never touched, and nobody can edit their own role.
router.patch('/users/:id/role', validateBody(assignRoleSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  if (!(await requireManager(req, res, 'manage_users'))) return;
  try {
    const targetId = req.params.id as string;
    if (targetId === req.user!.id) {
      res.status(400).json({ error: 'You cannot change your own role.' });
      return;
    }
    const target = await prisma.user.findUnique({ where: { id: targetId } });
    if (!target) {
      res.status(404).json({ error: 'User not found.' });
      return;
    }
    if (target.role === 'admin') {
      res.status(403).json({ error: 'A Principal account cannot be changed by anyone else.' });
      return;
    }
    const newRole = req.body.role;
    const imPermissions = newRole === 'im'
      ? (req.body.permissions && req.body.permissions.length > 0 ? req.body.permissions : null)
      : (newRole === 'hod' ? ['live_classes'] : null);

    const user = await prisma.user.update({
      where: { id: targetId },
      data: { role: newRole, imPermissions },
      select: { id: true, name: true, email: true, role: true, imPermissions: true },
    });
    await logActivity(req.user!.id, 'ROLE_ASSIGNED', { targetId, from: target.role, to: newRole });
    res.status(200).json({ user });
  } catch (error) {
    console.error('Assign role error:', error);
    res.status(500).json({ error: 'Failed to update the role.' });
  }
});

export default router;
