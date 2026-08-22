import { Router, Response } from 'express';
import { z } from 'zod';
import { RtcTokenBuilder, RtcRole } from 'agora-token';
import prisma from '../lib/prisma';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { requireConfig } from '../services/externalApi';
import { env } from '../lib/env';
import { assertOwnsSection } from './attendance';
import { notifySection } from '../services/notifications';

/**
 * Live classes: a teacher broadcasts to their Section over Agora (video/audio
 * SFU — this backend only ever issues short-lived RTC tokens and tracks
 * session metadata, never touches any media). One active broadcast per
 * Section at a time; starting a new one ends whatever was still open.
 */
const router = Router();
router.use(authenticate);

const TOKEN_TTL_SECONDS = 4 * 60 * 60; // 4 hours — generous for one class period

function requireAgoraConfig(res: Response) {
  return requireConfig(
    { AGORA_APP_ID: env.AGORA_APP_ID, AGORA_APP_CERTIFICATE: env.AGORA_APP_CERTIFICATE },
    res,
    'Live classes',
  );
}

const startSchema = z.object({
  title: z.string().trim().min(1).max(200),
  recordingAllowed: z.boolean().default(false),
});

const chatMessageSchema = z.object({
  message: z.string().trim().min(1).max(500).optional(),
  // Inline image share: a data-URI (data:image/...;base64,....). Kept small —
  // ~1.5MB of raw image bytes — so the polled stream stays light. Both fields
  // are optional but at least one must be present (a pure text message or a
  // pure image message).
  imageData: z
    .string()
    .max(2_100_000)
    .refine((v) => v.startsWith('data:image/'), {
      message: 'imageData must be a data:image URI',
    })
    .optional(),
}).refine((v) => v.message != null || v.imageData != null, {
  message: 'Provide a message or an image.',
});

// Whiteboard stroke: color as ARGB int, width in logical pixels, points as
// [[dx, dy], ...] normalized 0..1 fractions of the board area.
const boardEventSchema = z.object({
  type: z.enum(['stroke', 'clear']),
  payload: z
    .object({
      color: z.number().int().optional(),
      width: z.number().positive().max(64).optional(),
      points: z
        .array(z.tuple([z.number(), z.number()]).refine(([x, y]) => x >= 0 && x <= 1 && y >= 0 && y <= 1))
        .max(4000)
        .optional(),
    })
    .default({}),
});

// Membership check shared by the chat endpoints: the teacher who owns the
// session or a student enrolled in its section, and only while it's open.
// Principal / Institute Manager / HOD accounts may observe ANY live class —
// they are not enrolled, but can join to watch.
const MANAGER_ROLES = ['admin', 'im', 'hod'];

async function assertLiveAccess(liveId: string, userId: string, userRole: string) {
  const live = await prisma.liveSession.findUnique({ where: { id: liveId } });
  if (!live || live.endedAt) return null;
  if (live.teacherId === userId) return live;
  if ((MANAGER_ROLES as readonly string[]).includes(userRole)) return live;
  const enrollment = await prisma.enrollment.findUnique({
    where: { sectionId_studentId: { sectionId: live.sectionId, studentId: userId } },
  });
  return enrollment ? live : null;
}

// Teacher: start broadcasting to a section. Ends any live session already
// open for the same section first — one broadcast per section at a time.
router.post('/sections/:id/live/start', validateBody(startSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  const cfg = requireAgoraConfig(res);
  if (!cfg) return;
  try {
    const section = await assertOwnsSection(req.params.id as string, req.user!.id);
    if (!section) {
      res.status(404).json({ error: 'Section not found.' });
      return;
    }
    const live = await prisma.$transaction(async (tx) => {
      await tx.liveSession.updateMany({
        where: { sectionId: section.id, endedAt: null },
        data: { endedAt: new Date() },
      });
      const live = await tx.liveSession.create({
        data: {
          sectionId: section.id,
          teacherId: req.user!.id,
          title: req.body.title,
          recordingAllowed: req.body.recordingAllowed,
          channelName: '',
        },
      });
      const channelName = `live_${live.id}`;
      await tx.liveSession.update({ where: { id: live.id }, data: { channelName } });
      return live;
    });
    const channelName = `live_${live.id}`;

    // Every enrolled student gets a live-class notification; the app turns
    // these into a local push + a Classroom-tab badge (no push infra yet).
    const teacher = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: { name: true },
    });
    await notifySection(
      section,
      'live_class',
      `Live now: ${live.title}`,
      `${section.label} · ${teacher?.name ?? req.user!.email} just started a live class.`,
      '/classroom',
    );

    const token = RtcTokenBuilder.buildTokenWithUserAccount(
      cfg.AGORA_APP_ID,
      cfg.AGORA_APP_CERTIFICATE,
      channelName,
      req.user!.id,
      RtcRole.PUBLISHER,
      TOKEN_TTL_SECONDS,
      TOKEN_TTL_SECONDS,
    );
    res.status(201).json({
      liveSessionId: live.id,
      channelName,
      appId: cfg.AGORA_APP_ID,
      token,
      role: 'publisher',
      recordingAllowed: live.recordingAllowed,
      title: live.title,
    });
  } catch (error) {
    console.error('Start live class error:', error);
    res.status(500).json({ error: 'Failed to start the live class.' });
  }
});

// Student: is any section they're enrolled in live right now? One check
// across every class they've joined, for a single "Live now" banner.
router.get('/my-live', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const enrollments = await prisma.enrollment.findMany({
      where: { studentId: req.user!.id },
      select: { sectionId: true },
    });
    if (enrollments.length === 0) {
      res.status(200).json({ live: null });
      return;
    }
    const live = await prisma.liveSession.findFirst({
      where: { sectionId: { in: enrollments.map((e) => e.sectionId) }, endedAt: null },
      orderBy: { startedAt: 'desc' },
      include: { section: { select: { label: true } } },
    });
    if (!live) {
      res.status(200).json({ live: null });
      return;
    }
    res.status(200).json({
      live: {
        id: live.id,
        title: live.title,
        sectionLabel: live.section.label,
        startedAt: live.startedAt,
        recordingAllowed: live.recordingAllowed,
      },
    });
  } catch (error) {
    console.error('Get my-live status error:', error);
    res.status(500).json({ error: 'Failed to check live status.' });
  }
});

// Anyone enrolled (or the teacher) can check whether a section is currently
// live, so a student's classroom screen can show a "Live now" banner.
router.get('/sections/:id/live', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const sectionId = req.params.id as string;
    const isTeacher = (await assertOwnsSection(sectionId, req.user!.id)) !== null;
    if (!isTeacher) {
      const enrollment = await prisma.enrollment.findUnique({
        where: { sectionId_studentId: { sectionId, studentId: req.user!.id } },
      });
      if (!enrollment) {
        res.status(403).json({ error: 'You are not enrolled in this class.' });
        return;
      }
    }
    const live = await prisma.liveSession.findFirst({
      where: { sectionId, endedAt: null },
      orderBy: { startedAt: 'desc' },
    });
    if (!live) {
      res.status(200).json({ live: null });
      return;
    }
    res.status(200).json({
      live: {
        id: live.id,
        title: live.title,
        startedAt: live.startedAt,
        recordingAllowed: live.recordingAllowed,
      },
    });
  } catch (error) {
    console.error('Get live status error:', error);
    res.status(500).json({ error: 'Failed to check live status.' });
  }
});

// Mints a join token for an already-started session. Every participant gets a
// PUBLISHER grant: students can unmute and ask questions (their client joins
// as broadcaster with only the microphone track), while the app still shows
// them the audience UX. Every client re-fetches recordingAllowed from here
// rather than trusting a value it was handed earlier, so the teacher's own
// decision at start time is the single source of truth for every screen.
router.post('/live/:id/token', async (req: AuthRequest, res: Response): Promise<void> => {
  const cfg = requireAgoraConfig(res);
  if (!cfg) return;
  try {
    const live = await prisma.liveSession.findUnique({ where: { id: req.params.id as string } });
    if (!live || live.endedAt) {
      res.status(404).json({ error: 'This live class has ended or does not exist.' });
      return;
    }
    const isTeacher = live.teacherId === req.user!.id;
    if (!isTeacher && !(MANAGER_ROLES as readonly string[]).includes(req.user!.role)) {
      const enrollment = await prisma.enrollment.findUnique({
        where: { sectionId_studentId: { sectionId: live.sectionId, studentId: req.user!.id } },
      });
      if (!enrollment) {
        res.status(403).json({ error: 'You are not enrolled in this class.' });
        return;
      }
    }
    const token = RtcTokenBuilder.buildTokenWithUserAccount(
      cfg.AGORA_APP_ID,
      cfg.AGORA_APP_CERTIFICATE,
      live.channelName,
      req.user!.id,
      RtcRole.PUBLISHER,
      TOKEN_TTL_SECONDS,
      TOKEN_TTL_SECONDS,
    );
    res.status(200).json({
      liveSessionId: live.id,
      channelName: live.channelName,
      appId: cfg.AGORA_APP_ID,
      token,
      role: isTeacher ? 'publisher' : 'audience',
      recordingAllowed: live.recordingAllowed,
      title: live.title,
    });
  } catch (error) {
    console.error('Live class token error:', error);
    res.status(500).json({ error: 'Failed to join the live class.' });
  }
});

// Teacher: end the broadcast.
router.post('/live/:id/end', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const live = await prisma.liveSession.findUnique({ where: { id: req.params.id as string } });
    if (!live || live.teacherId !== req.user!.id) {
      res.status(404).json({ error: 'Live class not found.' });
      return;
    }
    await prisma.liveSession.update({ where: { id: live.id }, data: { endedAt: new Date() } });
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('End live class error:', error);
    res.status(500).json({ error: 'Failed to end the live class.' });
  }
});

// Chat stream for an open live class: teacher or any enrolled student.
// `after` is an epoch-millis cursor (the newest createdAt the client already
// has); the client polls while the class is open and appends what's new.
router.get('/live/:id/messages', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const live = await assertLiveAccess(req.params.id as string, req.user!.id, req.user!.role);
    if (!live) {
      res.status(404).json({ error: 'This live class has ended or does not exist.' });
      return;
    }
    const after = req.query.after as string | undefined;
    const afterDate = after && /^\d+$/.test(after) ? new Date(Number(after)) : undefined;
    const items = await prisma.liveChatMessage.findMany({
      where: { liveSessionId: live.id, ...(afterDate ? { createdAt: { gt: afterDate } } : {}) },
      orderBy: { createdAt: 'asc' },
      take: 200,
      select: { id: true, userId: true, name: true, message: true, imageData: true, createdAt: true },
    });
    res.status(200).json({
      items: items.map((m) => ({ ...m, isTeacher: m.userId === live.teacherId })),
    });
  } catch (error) {
    console.error('List live chat messages error:', error);
    res.status(500).json({ error: 'Failed to fetch chat messages.' });
  }
});

router.post('/live/:id/messages', validateBody(chatMessageSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const live = await assertLiveAccess(req.params.id as string, req.user!.id, req.user!.role);
    if (!live) {
      res.status(404).json({ error: 'This live class has ended or does not exist.' });
      return;
    }
    const sender = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: { name: true },
    });
    const message = await prisma.liveChatMessage.create({
      data: {
        liveSessionId: live.id,
        userId: req.user!.id,
        name: sender?.name ?? req.user!.email,
        message: req.body.message ?? '',
        imageData: req.body.imageData ?? null,
      },
      select: { id: true, userId: true, name: true, message: true, imageData: true, createdAt: true },
    });
    res.status(201).json({ ...message, isTeacher: message.userId === live.teacherId });
  } catch (error) {
    console.error('Send live chat message error:', error);
    res.status(500).json({ error: 'Failed to send the chat message.' });
  }
});

// Whiteboard events for an open live class, polled exactly like chat.
// `after` is the highest `seq` the client has; the server returns only newer
// events, oldest first, capped at 100 per poll.
router.get('/live/:id/board/events', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const live = await assertLiveAccess(req.params.id as string, req.user!.id, req.user!.role);
    if (!live) {
      res.status(404).json({ error: 'This live class has ended or does not exist.' });
      return;
    }
    const after = Number(req.query.after);
    const afterSeq = Number.isInteger(after) && after >= 0 ? after : 0;
    const events = await prisma.liveBoardEvent.findMany({
      where: { liveSessionId: live.id, seq: { gt: afterSeq } },
      orderBy: { seq: 'asc' },
      take: 100,
      select: { seq: true, type: true, payload: true },
    });
    const nextSeq = events.length > 0 ? events[events.length - 1]!.seq : afterSeq;
    res.status(200).json({ items: events, nextSeq });
  } catch (error) {
    console.error('List board events error:', error);
    res.status(500).json({ error: 'Failed to fetch whiteboard events.' });
  }
});

// Teacher only: appends one whiteboard event (a finished stroke or a clear).
// Students read the board; only the teacher draws.
router.post('/live/:id/board/events', validateBody(boardEventSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const live = await assertLiveAccess(req.params.id as string, req.user!.id, req.user!.role);
    if (!live) {
      res.status(404).json({ error: 'This live class has ended or does not exist.' });
      return;
    }
    if (live.teacherId !== req.user!.id) {
      res.status(403).json({ error: 'Only the teacher can draw on the whiteboard.' });
      return;
    }
    if (req.body.type === 'stroke') {
      if (req.body.payload.color == null || req.body.payload.points == null) {
        res.status(400).json({ error: 'A stroke event needs color and points.' });
        return;
      }
    }
    const event = await prisma.liveBoardEvent.create({
      data: {
        liveSessionId: live.id,
        type: req.body.type,
        payload: req.body.payload,
      },
      select: { seq: true, type: true, payload: true },
    });
    res.status(201).json(event);
  } catch (error) {
    console.error('Create board event error:', error);
    res.status(500).json({ error: 'Failed to save the whiteboard event.' });
  }
});

export default router;
