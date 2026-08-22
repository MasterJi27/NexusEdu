import { Router, Response } from 'express';
import crypto from 'crypto';
import { z } from 'zod';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { requireRole } from '../middlewares/error';
import { validateBody } from '../middlewares/validate';
import { tokenBucket } from '../middlewares/tokenBucket';
import { env } from '../lib/env';
import { findStudentByEmail } from '../services/userService';

const router = Router();

const CODE_TTL_MS = 25 * 1000;
const VALID_STATUSES = ['present', 'absent', 'late', 'leave'] as const;

// GPS error on a classroom phone is realistically 10-25m even in good
// conditions; the fence is about "are you in the room", not "are you on the
// teacher's desk", so this grace is folded into the radius comparison.
const GPS_GRACE_METERS = 20;

const EARTH_RADIUS_METERS = 6371000;

// Most colleges require 75% attendance to be eligible to sit an exam. Not
// configurable per-institution yet — the first real ask for a different
// number is the natural time to make this a Section-level setting instead.
const ATTENDANCE_ELIGIBILITY_THRESHOLD = 75;

function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return EARTH_RADIUS_METERS * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function isFiniteNumber(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v);
}

function hashCode(sessionId: string, code: string, expiresAt: Date): string {
  return crypto
    .createHmac('sha256', env.JWT_SECRET)
    .update(`${sessionId}:${code}:${expiresAt.toISOString()}`)
    .digest('hex');
}

function generateCode(): string {
  return String(crypto.randomInt(100000, 999999));
}

// 6 chars from a set without lookalikes (0/O, 1/I/L) so codes survive being
// read aloud or typed from a printed sheet.
const INVITE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
function generateInviteCode(): string {
  const bytes = crypto.randomBytes(6);
  return Array.from(bytes, (b) => INVITE_ALPHABET[b % INVITE_ALPHABET.length]).join('');
}

async function ensureInviteCode(section: { id: string; inviteCode: string | null }) {
  if (section.inviteCode) return section.inviteCode;
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateInviteCode();
    try {
      await prisma.section.update({
        where: { id: section.id },
        data: { inviteCode: code },
      });
      return code;
    } catch (error) {
      // Unique collision — retry with a fresh code.
    }
  }
  throw new Error('Could not allocate an invite code for the section.');
}

async function logAudit(
  action: string,
  actorId: string,
  extra: { sessionId?: string; recordId?: string; reason?: string; metadata?: any } = {},
) {
  try {
    await prisma.attendanceAudit.create({ data: { action, actorId, ...extra } });
  } catch (error) {
    console.error('Failed to write attendance audit:', error);
  }
}

// ---------------------------------------------------------------------------
// Sections (a teacher's own class roster)
// ---------------------------------------------------------------------------

const sectionSchema = z.object({
  label: z.string().trim().min(1).max(100),
  gradeLevel: z.string().trim().min(1).max(100),
  subject: z.string().trim().max(50).optional(),
  semester: z.string().trim().max(50).optional(),
});

router.post('/sections', authenticate, requireRole('teacher', 'admin'), validateBody(sectionSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await prisma.section.create({
      data: { ...req.body, teacherId: req.user!.id, inviteCode: generateInviteCode() },
    });
    res.status(201).json(section);
  } catch (error) {
    console.error('Create section error:', error);
    res.status(500).json({ error: 'Failed to create section.' });
  }
});

router.get('/sections', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const sections = await prisma.section.findMany({
      where: { teacherId: req.user!.id },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { enrollments: true } } },
    });
    // Backfill invite codes for sections created before QR sharing shipped.
    await Promise.all(sections.map((s) => ensureInviteCode(s).catch(() => null)));
    const refreshed = await prisma.section.findMany({
      where: { teacherId: req.user!.id },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { enrollments: true } } },
    });
    res.status(200).json(refreshed);
  } catch (error) {
    console.error('List sections error:', error);
    res.status(500).json({ error: 'Failed to fetch sections.' });
  }
});

// Student self-join: entering the classroom invite code (or scanning the QR
// the teacher shows) creates the enrollment immediately. Roll numbers can be
// corrected by the teacher afterwards.
const joinSectionSchema = z.object({
  inviteCode: z.string().trim().toUpperCase().min(6).max(6),
});

router.post('/sections/join', authenticate, requireRole('student', 'admin'), validateBody(joinSectionSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await prisma.section.findUnique({
      where: { inviteCode: req.body.inviteCode },
    });
    if (!section) {
      res.status(404).json({ error: 'No classroom found with that code. Check with your teacher.' });
      return;
    }
    const enrollment = await prisma.enrollment.upsert({
      where: { sectionId_studentId: { sectionId: section.id, studentId: req.user!.id } },
      create: { sectionId: section.id, studentId: req.user!.id },
      update: {},
      include: { section: { select: { id: true, label: true, gradeLevel: true, subject: true, semester: true } } },
    });
    res.status(200).json({ joined: true, section: enrollment.section });
  } catch (error) {
    console.error('Join section error:', error);
    res.status(500).json({ error: 'Failed to join the classroom.' });
  }
});

// Student: every section they've joined — a college student's electives can
// span several independently-owned sections in the same term, not one fixed
// class, so this is a list rather than a single "my class".
router.get('/my-sections', authenticate, requireRole('student', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: req.user!.id },
      include: {
        section: {
          select: {
            id: true,
            label: true,
            gradeLevel: true,
            subject: true,
            semester: true,
            teacher: { select: { name: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.status(200).json(
      enrollments.map((e) => ({
        ...e.section,
        teacherName: e.section.teacher.name,
      })),
    );
  } catch (error) {
    console.error('List my sections error:', error);
    res.status(500).json({ error: 'Failed to fetch your classes.' });
  }
});

export async function assertOwnsSection(sectionId: string, teacherId: string) {
  const section = await prisma.section.findUnique({ where: { id: sectionId } });
  if (!section || section.teacherId !== teacherId) return null;
  return section;
}

const enrollSchema = z.object({
  studentEmail: z.string().trim().email(),
  rollNumber: z.string().trim().max(20).optional(),
});

router.post('/sections/:id/students', authenticate, requireRole('teacher', 'admin'), validateBody(enrollSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await assertOwnsSection(req.params.id as string, req.user!.id);
    if (!section) {
      res.status(404).json({ error: 'Section not found.' });
      return;
    }
    const student = await findStudentByEmail(req.body.studentEmail);
    if (!student) {
      res.status(404).json({ error: 'No student account found with that email.' });
      return;
    }
    const enrollment = await prisma.enrollment.upsert({
      where: { sectionId_studentId: { sectionId: section.id, studentId: student.id } },
      create: { sectionId: section.id, studentId: student.id, rollNumber: req.body.rollNumber },
      update: { rollNumber: req.body.rollNumber },
      include: { student: { select: { id: true, name: true, email: true, photoUrl: true } } },
    });
    res.status(201).json(enrollment);
  } catch (error) {
    console.error('Enroll student error:', error);
    res.status(500).json({ error: 'Failed to add student.' });
  }
});

router.get('/sections/:id/students', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await assertOwnsSection(req.params.id as string, req.user!.id);
    if (!section) {
      res.status(404).json({ error: 'Section not found.' });
      return;
    }
    const enrollments = await prisma.enrollment.findMany({
      where: { sectionId: section.id },
      include: { student: { select: { id: true, name: true, email: true, photoUrl: true } } },
      orderBy: { rollNumber: 'asc' },
    });
    res.status(200).json(enrollments);
  } catch (error) {
    console.error('List roster error:', error);
    res.status(500).json({ error: 'Failed to fetch roster.' });
  }
});

router.delete('/sections/:id/students/:studentId', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await assertOwnsSection(req.params.id as string, req.user!.id);
    if (!section) {
      res.status(404).json({ error: 'Section not found.' });
      return;
    }
    await prisma.enrollment.deleteMany({
      where: { sectionId: section.id, studentId: req.params.studentId as string },
    });
    res.status(204).end();
  } catch (error) {
    console.error('Remove student error:', error);
    res.status(500).json({ error: 'Failed to remove student.' });
  }
});

// ---------------------------------------------------------------------------
// CSV roster import — paste-in, no file upload needed. One line per student:
//   email,rollNumber
//   student1@example.com,1
//   "student2@example.com",2
// A header line (email, roll) is tolerated and skipped. Students without an
// existing account are reported as failures so the teacher can send them the
// app link — we never silently create accounts from a paste.
// ---------------------------------------------------------------------------

const BULK_BODY_LIMIT = 200 * 1024; // ~2000 roster lines is plenty

router.post('/sections/:id/students/bulk', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await assertOwnsSection(req.params.id as string, req.user!.id);
    if (!section) {
      res.status(404).json({ error: 'Section not found.' });
      return;
    }
    const raw = req.body?.csv;
    if (typeof raw !== 'string' || raw.trim().length === 0) {
      res.status(400).json({ error: 'Send a "csv" field with one student per line: email,rollNumber.' });
      return;
    }
    if (raw.length > BULK_BODY_LIMIT) {
      res.status(413).json({ error: 'Roster is too large. Keep it under ~2000 students per import.' });
      return;
    }

    const rows: { email: string; rollNumber?: string }[] = [];
    const seen = new Set<string>();
    for (const line of raw.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      const [emailRaw, rollRaw] = trimmed.split(',');
      const email = (emailRaw ?? '').trim().replace(/^"|"$/g, '').toLowerCase();
      const roll = (rollRaw ?? '').trim().replace(/^"|"$/g, '');
      if (!email) continue;
      if (email === 'email' && roll.toLowerCase() === 'rollnumber') continue; // header
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) continue; // malformed line, skip silently
      if (seen.has(email)) continue;
      seen.add(email);
      rows.push({ email, rollNumber: roll || undefined });
    }

    const students = await prisma.user.findMany({
      where: { email: { in: rows.map((r) => r.email) }, role: 'student' },
      select: { id: true, email: true, name: true },
    });
    const byEmail = new Map(students.map((s) => [s.email.toLowerCase(), s]));
    const missingEmails = rows.filter((r) => !byEmail.has(r.email)).map((r) => r.email);

    const ops = rows
      .filter((r) => byEmail.has(r.email))
      .map((r) =>
        prisma.enrollment.upsert({
          where: { sectionId_studentId: { sectionId: section.id, studentId: byEmail.get(r.email)!.id } },
          create: { sectionId: section.id, studentId: byEmail.get(r.email)!.id, rollNumber: r.rollNumber },
          update: { rollNumber: r.rollNumber },
        }),
      );
    const created = await prisma.$transaction(ops);

    await logAudit('roster_imported', req.user!.id, {
      sessionId: section.id,
      metadata: { imported: created.length, skippedMissing: missingEmails.length },
      reason: 'bulk_csv',
    });

    res.status(201).json({
      imported: created.length,
      totalLines: rows.length,
      alreadyEnrolled: rows.length - missingEmails.length - created.length,
      missingStudents: missingEmails,
    });
  } catch (error) {
    console.error('Bulk import error:', error);
    res.status(500).json({ error: 'Failed to import roster.' });
  }
});

// ---------------------------------------------------------------------------
// Attendance sessions
// ---------------------------------------------------------------------------

const startSessionSchema = z.object({
  subject: z.string().trim().min(1).max(50),
  // Classroom anchor. Optional so a teacher who declines location sharing
  // (or a pre-fence client) can still run a session — it just records
  // distance null and accepts marks from anywhere, exactly like the
  // pre-fence behavior. When present, radius defaults to 75m (a large
  // lecture hall) if the client does not set one.
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
  radiusMeters: z.number().int().min(25).max(500).optional(),
});

router.post('/sections/:id/sessions', authenticate, requireRole('teacher', 'admin'), validateBody(startSessionSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const section = await assertOwnsSection(req.params.id as string, req.user!.id);
    if (!section) {
      res.status(404).json({ error: 'Section not found.' });
      return;
    }
    // Generated up front (rather than left to Prisma's default) so the code
    // hash can be bound to the session's id in the same write that creates it.
    const sessionId = crypto.randomUUID();
    const code = generateCode();
    const codeExpiresAt = new Date(Date.now() + CODE_TTL_MS);
    const session = await prisma.attendanceSession.create({
      data: {
        id: sessionId,
        sectionId: section.id,
        subject: req.body.subject,
        teacherId: req.user!.id,
        codeHash: hashCode(sessionId, code, codeExpiresAt),
        codeExpiresAt,
        lat: req.body.lat,
        lng: req.body.lng,
        radiusMeters: req.body.radiusMeters ?? 75,
      },
    });
    await logAudit('session_opened', req.user!.id, { sessionId: session.id });
    res.status(201).json({ ...session, code, codeTtlSeconds: CODE_TTL_MS / 1000 });
  } catch (error) {
    console.error('Start session error:', error);
    res.status(500).json({ error: 'Failed to start attendance session.' });
  }
});

// Student side: which of my enrolled sections currently has an open session,
// so the "mark attendance" screen has something to point at without the
// student needing to know an internal session id.
router.get('/my-open-sessions', authenticate, requireRole('student', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: req.user!.id },
      select: { sectionId: true, section: { select: { label: true } } },
    });
    if (enrollments.length === 0) {
      res.status(200).json([]);
      return;
    }
    const sessions = await prisma.attendanceSession.findMany({
      where: { sectionId: { in: enrollments.map((e) => e.sectionId) }, closedAt: null },
      orderBy: { openedAt: 'desc' },
    });
    const labelBySection = new Map(enrollments.map((e) => [e.sectionId, e.section.label]));
    res.status(200).json(
      sessions.map((s) => ({
        sessionId: s.id,
        subject: s.subject,
        sectionLabel: labelBySection.get(s.sectionId),
        openedAt: s.openedAt,
      })),
    );
  } catch (error) {
    console.error('List open sessions error:', error);
    res.status(500).json({ error: 'Failed to fetch open sessions.' });
  }
});

async function assertOwnsSession(sessionId: string, teacherId: string) {
  const session = await prisma.attendanceSession.findUnique({ where: { id: sessionId } });
  if (!session || session.teacherId !== teacherId) return null;
  return session;
}

// Teacher polls this every ~20s to keep a fresh code on screen. Rotating
// server-side (not just re-rendering the same code) is what makes a
// screenshot of the code worthless once the window closes.
router.get('/sessions/:id/code', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const session = await assertOwnsSession(req.params.id as string, req.user!.id);
    if (!session) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }
    if (session.closedAt) {
      res.status(400).json({ error: 'This session is closed.' });
      return;
    }
    if (session.codeExpiresAt > new Date()) {
      res.status(200).json({
        codeExpiresAt: session.codeExpiresAt,
        codeTtlSeconds: Math.round((session.codeExpiresAt.getTime() - Date.now()) / 1000),
      });
      return;
    }
    const code = generateCode();
    const codeExpiresAt = new Date(Date.now() + CODE_TTL_MS);
    const codeHash = hashCode(session.id, code, codeExpiresAt);
    await prisma.attendanceSession.update({
      where: { id: session.id },
      data: { codeHash, codeExpiresAt },
    });
    res.status(200).json({ code, codeExpiresAt, codeTtlSeconds: CODE_TTL_MS / 1000 });
  } catch (error) {
    console.error('Rotate code error:', error);
    res.status(500).json({ error: 'Failed to refresh code.' });
  }
});

// Reconciliation view: full roster cross-referenced with who has actually
// marked in. This is what lets a teacher catch "marked the whole class
// present without checking" — the live count makes the honest action
// (checking) faster than the dishonest one (not checking).
router.get('/sessions/:id/roster', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const session = await assertOwnsSession(req.params.id as string, req.user!.id);
    if (!session) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }
    const [enrollments, records] = await Promise.all([
      prisma.enrollment.findMany({
        where: { sectionId: session.sectionId },
        include: { student: { select: { id: true, name: true, photoUrl: true } } },
        orderBy: { rollNumber: 'asc' },
      }),
      prisma.attendanceRecord.findMany({ where: { sessionId: session.id } }),
    ]);
    const byStudent = new Map(records.map((r) => [r.studentId, r]));
    const roster = enrollments.map((e) => ({
      studentId: e.studentId,
      name: e.student.name,
      photoUrl: e.student.photoUrl,
      rollNumber: e.rollNumber,
      status: byStudent.get(e.studentId)?.status ?? null,
      markedVia: byStudent.get(e.studentId)?.markedVia ?? null,
      distanceMeters: byStudent.get(e.studentId)?.distanceMeters ?? null,
    }));
    const markedCount = roster.filter((r) => r.status !== null).length;
    res.status(200).json({
      session: { id: session.id, subject: session.subject, closedAt: session.closedAt },
      roster,
      totalStudents: roster.length,
      markedCount,
    });
  } catch (error) {
    console.error('Roster reconciliation error:', error);
    res.status(500).json({ error: 'Failed to fetch roster.' });
  }
});

const markSchema = z.object({
  code: z.string().trim().length(6),
  idempotencyKey: z.string().trim().min(8).max(120),
  clientMarkedAt: z.string().datetime().optional(),
  // Device-reported position. Optional only so a legitimately old client
  // (pre-geo-fence build) can still mark; the server records distance null.
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
  // Android's Position.isMocked — true when the fix came from a mock-location
  // (GPS spoofing) app. Optional so an older client can still mark; absent is
  // treated as "unknown", not "clean".
  isMocked: z.boolean().optional(),
});

// Token bucket keyed per (student, session): capacity 3, refills 1 every 30s.
// Absorbs a genuine retry on flaky classroom wifi without opening a window
// for a brute-force attempt against the 6-digit code.
const markLimiter = tokenBucket({
  capacity: 3,
  refillAmount: 1,
  refillIntervalMs: 30 * 1000,
  keyFn: (req) => `mark:${req.user!.id}:${req.params.id}`,
  message: 'Too many attempts for this session. Wait a moment and try again.',
});

router.post('/sessions/:id/mark', authenticate, requireRole('student', 'admin'), markLimiter, validateBody(markSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const session = await prisma.attendanceSession.findUnique({ where: { id: req.params.id as string } });
    if (!session) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }
    if (session.closedAt) {
      res.status(400).json({ error: 'This session is closed.' });
      return;
    }
    if (session.codeExpiresAt < new Date()) {
      res.status(400).json({ error: 'That code has expired. Ask your teacher for the current one.' });
      return;
    }
    const enrolled = await prisma.enrollment.findUnique({
      where: { sectionId_studentId: { sectionId: session.sectionId, studentId: req.user!.id } },
    });
    if (!enrolled) {
      res.status(403).json({ error: 'You are not enrolled in this section.' });
      return;
    }
    const submittedHash = hashCode(session.id, req.body.code, session.codeExpiresAt);
    if (submittedHash !== session.codeHash) {
      res.status(400).json({ error: 'Incorrect code.' });
      return;
    }

    // Geo-fence: when the session has an anchor, the student's device must
    // report a position inside it (with the GPS grace folded in). Rejections
    // still get logged to the audit trail so the classroom knows the attempt
    // happened and from how far away.
    let distanceMeters: number | undefined;
    if (isFiniteNumber(session.lat) && isFiniteNumber(session.lng) && isFiniteNumber(session.radiusMeters)) {
      // A self-declared spoofed fix is refused outright. This only stops the
      // casual case (a mock-location app on an unmodified build) — a patched
      // client can always omit or lie about the flag, which is why the code
      // itself stays short-lived and server-verified. Logged either way so a
      // pattern of attempts is visible to the school.
      if (req.body.isMocked === true) {
        await logAudit('mark_rejected_geofence', req.user!.id, {
          sessionId: session.id,
          reason: 'mock_location',
        });
        res.status(403).json({
          error: 'Your device reported a simulated location. Turn off any mock-location app and try again.',
        });
        return;
      }
      if (!isFiniteNumber(req.body.lat) || !isFiniteNumber(req.body.lng)) {
        await logAudit('mark_rejected_geofence', req.user!.id, {
          sessionId: session.id,
          reason: 'no_location_sent',
        });
        res.status(403).json({
          error: 'Location could not be read. Turn on location and try again.',
        });
        return;
      }
      distanceMeters = haversineMeters(
        session.lat,
        session.lng,
        req.body.lat,
        req.body.lng,
      );
      if (distanceMeters > session.radiusMeters + GPS_GRACE_METERS) {
        await logAudit('mark_rejected_geofence', req.user!.id, {
          sessionId: session.id,
          metadata: { distanceMeters: Math.round(distanceMeters), radiusMeters: session.radiusMeters },
          reason: 'outside_zone',
        });
        res.status(403).json({
          error: `You appear to be ${Math.round(distanceMeters)}m from the classroom.`,
        });
        return;
      }
    }

    try {
      const record = await prisma.attendanceRecord.create({
        data: {
          sessionId: session.id,
          studentId: req.user!.id,
          status: 'present',
          markedVia: 'code',
          idempotencyKey: req.body.idempotencyKey,
          clientMarkedAt: req.body.clientMarkedAt ? new Date(req.body.clientMarkedAt) : undefined,
          markedLat: req.body.lat,
          markedLng: req.body.lng,
          distanceMeters,
          wasMockedFix: req.body.isMocked,
        },
      });
      await logAudit('marked', req.user!.id, {
        sessionId: session.id,
        recordId: record.id,
        metadata: { distanceMeters: distanceMeters ? Math.round(distanceMeters) : null },
      });
      res.status(201).json({ ...record, distanceMeters });
    } catch (error: any) {
      // Unique violation on (sessionId, studentId) — the real idempotency
      // guard. A retried request lands here and should read as success, not
      // as an error, since the student is in fact marked.
      if (error?.code === 'P2002') {
        const existing = await prisma.attendanceRecord.findUnique({
          where: { sessionId_studentId: { sessionId: session.id, studentId: req.user!.id } },
        });
        if (existing) {
          res.status(200).json(existing);
        } else {
          // The unique violation was on the global idempotencyKey index, not
          // the (sessionId, studentId) one — this key was already used for a
          // different mark, so there is no record to return as "success".
          res.status(409).json({ error: 'This idempotency key was already used for a different mark.' });
        }
        return;
      }
      throw error;
    }
  } catch (error) {
    console.error('Mark attendance error:', error);
    res.status(500).json({ error: 'Failed to mark attendance.' });
  }
});

// Teacher offline-hotspot upload: the teacher's phone collects marks
// peer-to-peer (students on the hotspot or BLE beacon) and flushes them here
// when connectivity returns. The teacher's authenticated device vouches for
// the marks, so there is no rotating code — the same geofence, enrollment and
// per-(session, student) uniqueness rules still apply per row.
const batchMarkSchema = z.object({
  marks: z
    .array(
      z.object({
        studentId: z.string().trim().min(1).max(64),
        clientMarkedAt: z.string().datetime().optional(),
        lat: z.number().min(-90).max(90).optional(),
        lng: z.number().min(-180).max(180).optional(),
        isMocked: z.boolean().optional(),
      }),
    )
    .min(1)
    .max(200),
});

router.post('/sessions/:id/batch', authenticate, requireRole('teacher', 'admin'), validateBody(batchMarkSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const session = await assertOwnsSession(req.params.id as string, req.user!.id);
    if (!session) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }
    if (session.closedAt) {
      res.status(400).json({ error: 'This session is closed.' });
      return;
    }

    const studentIds: string[] = [...new Set((req.body.marks as Array<{ studentId: string }>).map((m) => m.studentId))];
    const enrollments = await prisma.enrollment.findMany({
      where: { sectionId: session.sectionId, studentId: { in: studentIds } },
    });
    const enrolled = new Set(enrollments.map((e) => e.studentId));
    const fenced =
      isFiniteNumber(session.lat) && isFiniteNumber(session.lng) && isFiniteNumber(session.radiusMeters);

    const results: Array<Record<string, unknown>> = [];
    // Marks that pass enrollment + geofence go here for a single batched
    // write below, instead of one `create` round trip per student.
    const candidates: Array<{
      studentId: string;
      clientMarkedAt?: string;
      lat?: number;
      lng?: number;
      isMocked?: boolean;
      distanceMeters?: number;
    }> = [];

    for (const m of req.body.marks as Array<{
      studentId: string;
      clientMarkedAt?: string;
      lat?: number;
      lng?: number;
      isMocked?: boolean;
    }>) {
      if (!enrolled.has(m.studentId)) {
        results.push({ studentId: m.studentId, ok: false, error: 'not_enrolled' });
        continue;
      }
      let distanceMeters: number | undefined;
      if (fenced) {
        if (m.isMocked === true) {
          results.push({ studentId: m.studentId, ok: false, error: 'mock_location' });
          continue;
        }
        if (!isFiniteNumber(m.lat) || !isFiniteNumber(m.lng)) {
          results.push({ studentId: m.studentId, ok: false, error: 'no_location' });
          continue;
        }
        distanceMeters = haversineMeters(session.lat!, session.lng!, m.lat, m.lng);
        if (distanceMeters > session.radiusMeters! + GPS_GRACE_METERS) {
          results.push({
            studentId: m.studentId,
            ok: false,
            error: 'outside_zone',
            distanceMeters: Math.round(distanceMeters),
          });
          continue;
        }
      }
      candidates.push({ ...m, distanceMeters });
    }

    // Find which candidates already have a record for this session in one
    // query, so they can be reported as duplicates without attempting (and
    // catching a P2002 on) an individual insert for each.
    const existing = candidates.length
      ? await prisma.attendanceRecord.findMany({
          where: { sessionId: session.id, studentId: { in: candidates.map((c) => c.studentId) } },
          select: { studentId: true },
        })
      : [];
    const alreadyMarked = new Set(existing.map((e) => e.studentId));
    const toCreate = candidates.filter((c) => !alreadyMarked.has(c.studentId));

    let created = 0;
    // Tracks which of `toCreate` actually have a row after the write, so a
    // student whose insert was silently skipped by `skipDuplicates` (the rare
    // concurrent-batch race) is not reported as `present` when nothing was
    // written for them.
    const actuallyCreated = new Set<string>();
    if (toCreate.length) {
      const { count } = await prisma.attendanceRecord.createMany({
        data: toCreate.map((m) => ({
          sessionId: session.id,
          studentId: m.studentId,
          status: 'present',
          markedVia: 'hotspot',
          idempotencyKey: `hotspot:${session.id}:${m.studentId}:${m.clientMarkedAt ?? 'manual'}`,
          clientMarkedAt: m.clientMarkedAt ? new Date(m.clientMarkedAt) : undefined,
          markedLat: m.lat,
          markedLng: m.lng,
          distanceMeters: m.distanceMeters,
          wasMockedFix: m.isMocked,
        })),
        // Safety net for the rare race (a concurrent batch already inserted
        // the same student between the findMany above and this write) — the
        // pre-check above is what makes per-student duplicate reporting
        // accurate in the common case.
        skipDuplicates: true,
      });
      created = count;
      if (count === toCreate.length) {
        for (const m of toCreate) actuallyCreated.add(m.studentId);
      } else {
        // Some inserts were skipped by the race above — check which rows
        // actually exist now instead of assuming every candidate landed.
        const confirmed = await prisma.attendanceRecord.findMany({
          where: { sessionId: session.id, studentId: { in: toCreate.map((m) => m.studentId) } },
          select: { studentId: true },
        });
        for (const c of confirmed) actuallyCreated.add(c.studentId);
      }
    }

    for (const m of candidates) {
      if (alreadyMarked.has(m.studentId)) {
        results.push({ studentId: m.studentId, ok: true, status: 'duplicate' });
      } else if (actuallyCreated.has(m.studentId)) {
        results.push({ studentId: m.studentId, ok: true, status: 'present', distanceMeters: m.distanceMeters });
      } else {
        results.push({ studentId: m.studentId, ok: false, error: 'write_failed' });
      }
    }
    await logAudit('hotspot_batch', req.user!.id, {
      sessionId: session.id,
      metadata: {
        total: req.body.marks.length,
        created,
        rejected: results.filter((r) => r.ok !== true).length,
      },
    });
    res.status(200).json({ results });
  } catch (error) {
    console.error('Batch mark error:', error);
    res.status(500).json({ error: 'Failed to process attendance batch.' });
  }
});

const overrideSchema = z.object({
  studentId: z.string().min(1),
  status: z.enum(VALID_STATUSES),
  reason: z.string().trim().min(1).max(300),
});

router.post('/sessions/:id/override', authenticate, requireRole('teacher', 'admin'), validateBody(overrideSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const session = await assertOwnsSession(req.params.id as string, req.user!.id);
    if (!session) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }
    const enrollment = await prisma.enrollment.findFirst({
      where: { sectionId: session.sectionId, studentId: req.body.studentId },
    });
    if (!enrollment) {
      res.status(400).json({ error: 'That student is not enrolled in this section.' });
      return;
    }
    const record = await prisma.attendanceRecord.upsert({
      where: { sessionId_studentId: { sessionId: session.id, studentId: req.body.studentId } },
      create: {
        sessionId: session.id,
        studentId: req.body.studentId,
        status: req.body.status,
        markedVia: 'teacher_override',
        idempotencyKey: `override:${session.id}:${req.body.studentId}:${Date.now()}`,
      },
      update: { status: req.body.status, markedVia: 'teacher_override' },
    });
    await logAudit('overridden', req.user!.id, {
      sessionId: session.id,
      recordId: record.id,
      reason: req.body.reason,
    });
    res.status(200).json(record);
  } catch (error) {
    console.error('Override attendance error:', error);
    res.status(500).json({ error: 'Failed to override attendance.' });
  }
});

router.post('/sessions/:id/close', authenticate, requireRole('teacher', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const session = await assertOwnsSession(req.params.id as string, req.user!.id);
    if (!session) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }
    await prisma.attendanceSession.update({
      where: { id: session.id },
      data: { closedAt: new Date() },
    });
    await logAudit('session_closed', req.user!.id, { sessionId: session.id });
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Close session error:', error);
    res.status(500).json({ error: 'Failed to close session.' });
  }
});

// ---------------------------------------------------------------------------
// History views — student's own, and a parent's for an APPROVED-linked child
// ---------------------------------------------------------------------------

async function historyFor(studentId: string, days: number) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const records = await prisma.attendanceRecord.findMany({
    where: { studentId, serverMarkedAt: { gte: since } },
    include: { session: { select: { subject: true, date: true, section: { select: { label: true } } } } },
    orderBy: { serverMarkedAt: 'desc' },
  });
  const total = records.length;
  const present = records.filter((r) => r.status === 'present' || r.status === 'late').length;
  const percentage = total > 0 ? Math.round((present / total) * 100) : null;
  return {
    records: records.map((r) => ({
      id: r.id,
      status: r.status,
      subject: r.session.subject,
      section: r.session.section.label,
      date: r.session.date,
    })),
    summary: {
      total,
      present,
      percentage,
      // College-style eligibility rule: most institutions require 75%
      // attendance to sit an exam. Null (not enough data yet) is neither
      // eligible nor ineligible — the UI should show "not enough data", not
      // guess.
      eligibilityThreshold: ATTENDANCE_ELIGIBILITY_THRESHOLD,
      eligible: percentage === null ? null : percentage >= ATTENDANCE_ELIGIBILITY_THRESHOLD,
    },
  };
}

router.get('/my-history', authenticate, requireRole('student', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const days = Math.min(Number(req.query.days) || 30, 180);
    res.status(200).json(await historyFor(req.user!.id, days));
  } catch (error) {
    console.error('Attendance history error:', error);
    res.status(500).json({ error: 'Failed to fetch attendance history.' });
  }
});

router.get('/child/:studentId/history', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const link = await prisma.parentLink.findUnique({
      where: { parentId_studentId: { parentId: req.user!.id, studentId: req.params.studentId as string } },
    });
    if (!link || link.status !== 'approved') {
      res.status(403).json({ error: 'This student has not approved sharing their data with you.' });
      return;
    }
    const days = Math.min(Number(req.query.days) || 30, 180);
    res.status(200).json(await historyFor(req.params.studentId as string, days));
  } catch (error) {
    console.error('Child attendance history error:', error);
    res.status(500).json({ error: 'Failed to fetch attendance history.' });
  }
});

// ---------------------------------------------------------------------------
// Parent digest — the "what happened today at school" answer. Per-day rollup
// across every approved child: session count per status and the sessions that
// were missed or late, which is the only part a parent actually acts on.
// ---------------------------------------------------------------------------

router.get('/digest', authenticate, requireRole('parent', 'admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const days = Math.min(Number(req.query.days) || 7, 30);
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const links = await prisma.parentLink.findMany({
      where: { parentId: req.user!.id, status: 'approved' },
      include: { student: { select: { id: true, name: true, photoUrl: true } } },
    });
    if (links.length === 0) {
      res.status(200).json({ children: [] });
      return;
    }

    const records = await prisma.attendanceRecord.findMany({
      where: {
        studentId: { in: links.map((l) => l.studentId) },
        serverMarkedAt: { gte: since },
      },
      include: {
        session: { select: { subject: true, date: true, section: { select: { label: true } } } },
      },
      orderBy: { serverMarkedAt: 'asc' },
    });

    const byStudent = new Map<string, typeof records>(links.map((l) => [l.studentId, []]));
    for (const r of records) byStudent.get(r.studentId)?.push(r);

    const children = links.map((link) => {
      const childRecords = byStudent.get(link.studentId) ?? [];
      const byDate = new Map<string, typeof childRecords>();
      for (const r of childRecords) {
        const key = r.session.date.toISOString().slice(0, 10);
        const list = byDate.get(key) ?? [];
        list.push(r);
        byDate.set(key, list);
      }
      const daysOut = [...byDate.entries()]
        .sort(([a], [b]) => (a < b ? 1 : -1))
        .map(([date, list]) => ({
          date,
          total: list.length,
          present: list.filter((r) => r.status === 'present').length,
          late: list.filter((r) => r.status === 'late').length,
          absent: list.filter((r) => r.status === 'absent').length,
          leave: list.filter((r) => r.status === 'leave').length,
          sessions: list.map((r) => ({
            subject: r.session.subject,
            section: r.session.section.label,
            status: r.status,
          })),
        }));
      const presentCount = childRecords.filter(
        (r) => r.status === 'present' || r.status === 'late',
      ).length;
      return {
        studentId: link.studentId,
        name: link.student.name,
        photoUrl: link.student.photoUrl,
        summary: {
          total: childRecords.length,
          present: presentCount,
          percentage:
            childRecords.length > 0
              ? Math.round((presentCount / childRecords.length) * 100)
              : null,
        },
        days: daysOut,
      };
    });

    res.status(200).json({ days, children });
  } catch (error) {
    console.error('Parent digest error:', error);
    res.status(500).json({ error: 'Failed to fetch digest.' });
  }
});

export default router;
