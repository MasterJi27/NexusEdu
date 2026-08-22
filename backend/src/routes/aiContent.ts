import { Router, Response } from 'express';
import { z } from 'zod';
import multer from 'multer';
import prisma from '../lib/prisma';
import { env } from '../lib/env';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { aiRateLimit } from '../middlewares/aiRateLimit';
import { groqChat, getAiQuota, reserveQuota, settleQuota, trackAiUsage } from '../services/aiService';
import { requireConfig } from '../services/externalApi';

/**
 * AI content endpoints: voice (STT + TTS), quiz generation, assignment
 * grading and the parent digest. All providers are free-tier and all calls
 * run through the shared quota + usage pipeline in aiService.
 */

const router = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 },
});

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

// Speech-to-text: audio upload -> whisper (free, 2000 req/day on Groq).
router.post('/transcribe', authenticate, aiRateLimit, upload.single('audio'), async (req: AuthRequest, res: Response): Promise<void> => {
  const cfg = requireConfig({ GROQ_API_KEY: env.GROQ_API_KEY }, res, 'Voice');
  if (!cfg) return;
  const file = (req as AuthRequest & { file?: Express.Multer.File }).file;
  if (!file) {
    res.status(400).json({ error: 'No audio file uploaded (field name: audio).' });
    return;
  }
  const userId = req.user!.id;

  // Whisper has no token count of its own, but this endpoint used to run
  // entirely outside the shared quota/usage pipeline every other AI feature
  // draws from — unlimited free transcription regardless of budget. Scaled
  // by upload size (not a flat number) so a large file actually costs more
  // of the shared budget instead of every upload — up to the 15MB limit —
  // charging the same 500 tokens.
  const ESTIMATED_TOKENS = Math.max(500, Math.ceil(file.buffer.length / 1024) * 5);

  // reserveQuota must sit inside the try: if it rejects (DB hiccup), the
  // catch below settles nothing and answers 500 instead of hanging the
  // request on an unhandled rejection.
  let reservation: { allowed: boolean; reservedTokens: number } | undefined;
  try {
    reservation = await reserveQuota(userId, ESTIMATED_TOKENS);
    if (!reservation.allowed) {
      res.status(429).json({ error: 'AI token budget exhausted - tokens refill continuously', quota: reservation });
      return;
    }

    const form = new FormData();
    form.append(
      'file',
      new Blob([Buffer.from(file.buffer)], { type: file.mimetype || 'audio/webm' }),
      file.originalname || 'recording.webm',
    );
    form.append('model', 'whisper-large-v3-turbo');

    const response = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${cfg.GROQ_API_KEY}` },
      body: form,
      signal: AbortSignal.timeout(60_000),
    });
    const data = await response.json();
    if (!response.ok) {
      await settleQuota(userId, reservation.reservedTokens, 0);
      res.status(502).json({ error: 'Transcription failed', details: data?.error?.message || data });
      return;
    }
    await trackAiUsage({
      userId,
      feature: 'transcribe',
      model: 'whisper-large-v3-turbo',
      endpoint: '/api/ai/transcribe',
      promptTokens: 0,
      completionTokens: ESTIMATED_TOKENS,
    });
    res.json({ text: data.text || '' });
  } catch (error: any) {
    if (reservation) {
      await settleQuota(userId, reservation.reservedTokens, 0);
    }
    console.error('Transcribe error:', error);
    res.status(500).json({ error: 'Transcription failed', details: error.message });
  }
});

const speechSchema = z.object({
  text: z.string().trim().min(1).max(1000),
  voice: z.string().max(50).optional(),
});

// Text-to-speech: text -> wav audio (free Orpheus voices on Groq).
const ORPHEUS_VOICES = ['autumn', 'diana', 'hannah', 'austin', 'daniel', 'troy'] as const;

router.post('/speech', authenticate, aiRateLimit, validateBody(speechSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  const cfg = requireConfig({ GROQ_API_KEY: env.GROQ_API_KEY }, res, 'Voice');
  if (!cfg) return;
  const { text, voice } = req.body;
  const safeVoice = ORPHEUS_VOICES.includes(voice) ? voice : 'hannah';
  const userId = req.user!.id;

  // Same reasoning as /transcribe: no native token count, but this must not
  // bypass the shared budget every other AI feature draws from. Estimated
  // from input length (~4 chars/token) rather than a flat number, since
  // synthesis cost scales with the text.
  const estimatedTokens = Math.max(50, Math.ceil(text.length / 4));
  let reservation: { allowed: boolean; reservedTokens: number } | undefined;
  try {
    reservation = await reserveQuota(userId, estimatedTokens);
    if (!reservation.allowed) {
      res.status(429).json({ error: 'AI token budget exhausted - tokens refill continuously', quota: reservation });
      return;
    }

    const response = await fetch('https://api.groq.com/openai/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cfg.GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'canopylabs/orpheus-v1-english',
        voice: safeVoice,
        input: text,
        response_format: 'wav',
      }),
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) {
      await settleQuota(userId, reservation.reservedTokens, 0);
      const body = await response.text();
      res.status(502).json({ error: 'Speech synthesis failed', details: body.slice(0, 300) });
      return;
    }
    await trackAiUsage({
      userId,
      feature: 'speech',
      model: 'canopylabs/orpheus-v1-english',
      endpoint: '/api/ai/speech',
      promptTokens: estimatedTokens,
      completionTokens: 0,
    });
    const buffer = Buffer.from(await response.arrayBuffer());
    res.set('Content-Type', 'audio/wav');
    res.set('Content-Length', String(buffer.length));
    res.send(buffer);
  } catch (error: any) {
    if (reservation) {
      await settleQuota(userId, reservation.reservedTokens, 0);
    }
    console.error('Speech error:', error);
    res.status(500).json({ error: 'Speech synthesis failed', details: error.message });
  }
});

// ---------------------------------------------------------------------------
// Quiz generation (structured JSON)
// ---------------------------------------------------------------------------

const quizSchema = z.object({
  topic: z.string().trim().min(1).max(200),
  subject: z.string().trim().min(1).max(50),
  gradeLevel: z.string().trim().max(20).optional(),
  count: z.number().int().min(3).max(15).optional(),
});

router.post('/generate-quiz', authenticate, aiRateLimit, validateBody(quizSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  const { topic, subject, gradeLevel, count = 5 } = req.body;
  const userId = req.user!.id;

  try {
    const quota = await getAiQuota(userId);
    if (!quota.allowed) {
      res.status(429).json({ error: 'AI token budget exhausted - tokens refill continuously', quota });
      return;
    }

    const data = await groqChat({
      messages: [
        {
          role: 'system',
          content:
            `You are a quiz generator for Indian students (CBSE, ICSE, JEE, NEET). ` +
            `Generate exactly ${count} multiple-choice questions on "${topic}" for ${subject}` +
            `${gradeLevel ? ` (grade ${gradeLevel})` : ''}. ` +
            `Difficulty: school-exam level. Respond ONLY with valid JSON: ` +
            `{"questions":[{"question":"...","options":["A","B","C","D"],"correctIndex":0,"explanation":"..."}]}`,
        },
        { role: 'user', content: 'Generate the quiz now.' },
      ],
      temperature: 0.4,
      maxTokens: 3000,
      feature: 'quiz',
      userId,
      jsonMode: true,
    });

    const raw = data.choices[0]?.message?.content || '{}';
    const parsed = JSON.parse(raw);
    const questions = Array.isArray(parsed?.questions) ? parsed.questions : [];
    if (questions.length === 0) {
      res.status(502).json({ error: 'The model returned no valid questions.', raw });
      return;
    }

    const quotaAfter = await getAiQuota(userId);
    res.json({
      topic,
      subject,
      count: questions.length,
      questions: questions.slice(0, 15),
      usage: {
        prompt_tokens: data.usage?.prompt_tokens || 0,
        completion_tokens: data.usage?.completion_tokens || 0,
        total_tokens: data.usage?.total_tokens || 0,
        remaining_today: quotaAfter.remainingTokens,
      },
    });
  } catch (error: any) {
    console.error('Quiz generation error:', error);
    res.status(error.statusCode || 500).json({
      error: 'Quiz generation failed',
      details: error.message,
      ...(error.quota ? { quota: error.quota } : {}),
    });
  }
});

// ---------------------------------------------------------------------------
// Assignment grading (rubric JSON)
// ---------------------------------------------------------------------------

const gradeSchema = z.object({
  title: z.string().trim().max(200).optional(),
  content: z.string().trim().min(20).max(20000),
  maxScore: z.number().int().min(1).max(100).optional(),
});

router.post('/grade-assignment', authenticate, aiRateLimit, validateBody(gradeSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  const { title, content, maxScore = 10 } = req.body;
  const userId = req.user!.id;

  try {
    const quota = await getAiQuota(userId);
    if (!quota.allowed) {
      res.status(429).json({ error: 'AI token budget exhausted - tokens refill continuously', quota });
      return;
    }

    const data = await groqChat({
      messages: [
        {
          role: 'system',
          content:
            'You are a fair, encouraging teacher who grades student work on a ' +
            `${maxScore}-point scale. Respond ONLY with valid JSON: ` +
            `{"score":0,"maxScore":${maxScore},"overallFeedback":"...","strengths":["..."],` +
            `"weaknesses":["..."],"grammarIssues":["..."]}. ` +
            'Be specific and constructive; never harsh. If the work is off-topic or ' +
            'unsafe, score it low and explain why.',
        },
        {
          role: 'user',
          content: `${title ? `Assignment: ${title}\n\n` : ''}Student work:\n\n${content}`,
        },
      ],
      temperature: 0.3,
      maxTokens: 1500,
      feature: 'grader',
      userId,
      jsonMode: true,
    });

    const raw = data.choices[0]?.message?.content || '{}';
    const parsed = JSON.parse(raw);
    if (typeof parsed?.score !== 'number') {
      res.status(502).json({ error: 'The model returned no valid grade.', raw });
      return;
    }

    const quotaAfter = await getAiQuota(userId);
    res.json({
      ...parsed,
      usage: {
        prompt_tokens: data.usage?.prompt_tokens || 0,
        completion_tokens: data.usage?.completion_tokens || 0,
        total_tokens: data.usage?.total_tokens || 0,
        remaining_today: quotaAfter.remainingTokens,
      },
    });
  } catch (error: any) {
    console.error('Assignment grading error:', error);
    res.status(error.statusCode || 500).json({
      error: 'Grading failed',
      details: error.message,
      ...(error.quota ? { quota: error.quota } : {}),
    });
  }
});

// ---------------------------------------------------------------------------
// Parent digest (in-app AI summary)
// ---------------------------------------------------------------------------

// Last 7 days of activity per child, summarized by the AI. Mirrors the email
// digest but always available in-app, even without SMTP configured.
router.get('/parent-digest', authenticate, aiRateLimit, async (req: AuthRequest, res: Response): Promise<void> => {
  const parentId = req.user!.id;

  try {
    const links = await prisma.parentLink.findMany({
      where: { parentId, status: 'approved' },
      include: {
        student: {
          select: { id: true, name: true, xp: true, streak: true, gradeLevel: true },
        },
      },
    });
    if (links.length === 0) {
      res.json({ children: [], note: 'No approved child links.' });
      return;
    }

    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const records = await prisma.attendanceRecord.findMany({
      where: {
        studentId: { in: links.map((l) => l.studentId) },
        serverMarkedAt: { gte: since },
      },
      include: {
        session: { select: { subject: true } },
      },
    });

    const children = links.map((link) => {
      const studentRecords = records.filter((r) => r.studentId === link.studentId);
      const counts = { present: 0, absent: 0, late: 0, leave: 0 };
      for (const r of studentRecords) {
        counts[r.status as keyof typeof counts] = (counts[r.status as keyof typeof counts] ?? 0) + 1;
      }
      const missedSubjects = Array.from(
        new Set(
          studentRecords
            .filter((r) => r.status === 'absent' || r.status === 'late' || r.status === 'leave')
            .map((r) => r.session.subject),
        ),
      );
      return {
        id: link.student.id,
        name: link.student.name,
        gradeLevel: link.student.gradeLevel,
        xp: link.student.xp,
        streak: link.student.streak,
        attendance: { total: studentRecords.length, ...counts },
        missedSubjects,
      };
    });

    let aiInsight: string | null = null;
    try {
      const summaryText = children
        .map(
          (c) =>
            `${c.name} (grade ${c.gradeLevel ?? '?'}): ${c.attendance.present}/${c.attendance.total} sessions, ` +
            `missed: ${c.missedSubjects.join(', ') || 'none'}, XP ${c.xp}, streak ${c.streak} days`,
        )
        .join('; ');

      const data = await groqChat({
        messages: [
          {
            role: 'system',
            content:
              'You write brief, warm, plain-English summaries for parents of school students. ' +
              'Respond in at most 3 short sentences per child, highlighting wins and gentle ' +
              'suggestions. No markdown, no lists.',
          },
          { role: 'user', content: `Last 7 days: ${summaryText}` },
        ],
        temperature: 0.5,
        maxTokens: 300,
        feature: 'parent-digest',
        userId: parentId,
      });
      aiInsight = data.choices[0]?.message?.content?.trim() || null;
    } catch (error) {
      console.error('Parent digest AI insight failed:', error);
    }

    res.json({ children, aiInsight, windowDays: 7 });
  } catch (error: any) {
    console.error('Parent digest error:', error);
    res.status(500).json({ error: 'Failed to build digest', details: error.message });
  }
});

export default router;
