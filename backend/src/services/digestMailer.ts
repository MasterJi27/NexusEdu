import nodemailer, { Transporter } from 'nodemailer';
import prisma from '../lib/prisma';
import { env } from '../lib/env';
import { groqChat } from './aiService';
import { isGmailConnected, sendViaComposio } from './composioMailer';

// Daily parent digest emails — entirely optional. Without any mail backend
// (SMTP_* vars or COMPOSIO_API_KEY with a connected Gmail) the digest stays
// in-app (GET /api/attendance/digest) and this module never sends a single
// email. Delivery order: Composio Gmail first, then SMTP.

let transporter: Transporter | null = null;

function getTransporter(): Transporter | null {
  if (!env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASS) return null;
  if (transporter) return transporter;
  transporter = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_PORT === 465,
    auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
  });
  return transporter;
}

/** True when at least one delivery path exists (Composio or SMTP). */
function hasMailDelivery(): boolean {
  return Boolean(env.COMPOSIO_API_KEY) || getTransporter() !== null;
}

function formatStatus(status: string): string {
  switch (status) {
    case 'present':
      return 'present';
    case 'late':
      return 'late';
    case 'absent':
      return 'absent';
    case 'leave':
      return 'on leave';
    default:
      return status;
  }
}

/**
 * AI-generated 2-3 sentence insight per child for the digest email. Best
 * effort: any failure returns null and the email still goes out without it.
 */
async function buildAiInsight(
  children: {
    name: string;
    present: number;
    total: number;
    missed: { subject: string; section: string; status: string }[];
  }[],
): Promise<string | null> {
  if (!env.GROQ_API_KEY) return null;
  try {
    const summaryText = children
      .map(
        (c) =>
          `${c.name}: ${c.present}/${c.total} sessions, missed: ` +
          `${c.missed.map((m) => m.subject).join(', ') || 'none'}`,
      )
      .join('; ');
    const data = await groqChat({
      messages: [
        {
          role: 'system',
          content:
            'You write brief, warm, plain-English insights for parents of school students. ' +
            'At most 2 sentences per child. Highlight wins, then one gentle suggestion if ' +
            'anything was missed. No markdown, no lists, no names of providers.',
        },
        { role: 'user', content: `Yesterday: ${summaryText}` },
      ],
      temperature: 0.5,
      maxTokens: 250,
      feature: 'parent-digest',
      userId: 'digest-worker',
    });
    return data.choices[0]?.message?.content?.trim() || null;
  } catch (error) {
    console.error('Digest AI insight failed:', error);
    return null;
  }
}

export async function sendDigestEmail(
  toEmail: string,
  parentName: string,
  children: {
    name: string;
    total: number;
    present: number;
    missed: { subject: string; section: string; status: string }[];
  }[],
  aiInsight?: string | null,
): Promise<boolean> {
  if (!hasMailDelivery()) return false;

  const childLines = children
    .map((c) => {
      const missLines =
        c.missed.length > 0
          ? `\n      - ${c.missed.map((m) => `${m.subject} (${m.section}): ${formatStatus(m.status)}`).join('\n      - ')}`
          : '';
      return `    • ${c.name} — ${c.present}/${c.total} sessions${missLines}`;
    })
    .join('\n');

  const subject = "Your child's attendance — daily digest";
  const body =
    `Hi ${parentName},\n\n` +
    `Here is yesterday's attendance across your approved children:\n\n${childLines}\n\n` +
    (aiInsight ? `What it means:\n\n${aiInsight}\n\n` : '') +
    `Open the Nexus Edu app for the full history.`;

  // 1) Composio Gmail (no SMTP needed)
  if (env.COMPOSIO_API_KEY) {
    try {
      if (await isGmailConnected()) {
        await sendViaComposio({ to: toEmail, subject, body });
        return true;
      }
      console.warn('Composio configured but no Gmail connected; falling back to SMTP.');
    } catch (error) {
      console.error('Composio email failed; falling back to SMTP:', error);
    }
  }

  // 2) SMTP
  const t = getTransporter();
  if (!t) return false;
  try {
    await t.sendMail({ from: env.DIGEST_FROM_EMAIL, to: toEmail, subject, text: body });
    return true;
  } catch (error) {
    console.error('Digest email failed:', error);
    return false;
  }
}

// Yesterday's records only, grouped per approved parent. Returns nothing when
// no mail backend is configured (callers treat it as a silent skip).
export async function runDailyDigest(): Promise<void> {
  if (!hasMailDelivery() || !env.DIGEST_ENABLED) return;

  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const yesterdayStart = new Date(startOfToday.getTime() - 24 * 60 * 60 * 1000);
  const yesterdayEnd = startOfToday;

  const links = await prisma.parentLink.findMany({
    where: { status: 'approved' },
    include: { parent: { select: { id: true, email: true, name: true } } },
  });
  if (links.length === 0) return;

  const studentIds = links.map((l) => l.studentId);
  const records = await prisma.attendanceRecord.findMany({
    where: {
      studentId: { in: studentIds },
      serverMarkedAt: { gte: yesterdayStart, lt: yesterdayEnd },
    },
    include: {
      session: { select: { subject: true, section: { select: { label: true } } } },
      student: { select: { name: true } },
    },
  });
  if (records.length === 0) return;

  const recordsByStudent = new Map<string, typeof records>();
  for (const r of records) {
    const list = recordsByStudent.get(r.studentId) ?? [];
    list.push(r);
    recordsByStudent.set(r.studentId, list);
  }
  const parentLinkByStudent = new Map(links.map((l) => [l.studentId, l]));

  const parents = new Map<string, { parent: (typeof links)[0]['parent']; children: any[] }>();
  for (const [studentId, list] of recordsByStudent) {
    const link = parentLinkByStudent.get(studentId);
    if (!link) continue;
    const entry = parents.get(link.parent.id) ?? {
      parent: link.parent,
      children: [],
    };
    entry.children.push({
      name: list[0].student.name,
      total: list.length,
      present: list.filter((r) => r.status === 'present' || r.status === 'late').length,
      missed: list
        .filter((r) => r.status === 'absent' || r.status === 'leave' || r.status === 'late')
        .map((r) => ({
          subject: r.session.subject,
          section: r.session.section.label,
          status: r.status,
        })),
    });
    parents.set(link.parent.id, entry);
  }

  await Promise.all(
    [...parents.values()].map(async ({ parent, children }) => {
      const aiInsight = await buildAiInsight(children);
      await sendDigestEmail(parent.email, parent.name || 'Parent', children, aiInsight);
    }),
  );
}

// One-shot guard so hot-reloading dev servers don't stack intervals.
let workerStarted = false;

export function startDigestEmailWorker(): void {
  if (workerStarted) return;
  workerStarted = true;
  if (!hasMailDelivery()) {
    console.log('Digest email worker: no mail backend (Composio/SMTP), in-app digest only.');
    return;
  }
  const run = () => runDailyDigest().catch((e) => console.error('Digest worker error:', e));
  // Run ~2 minutes after startup (misses nothing, avoids racing the boot)
  // and then once a day.
  setTimeout(run, 2 * 60 * 1000);
  setInterval(run, 24 * 60 * 60 * 1000);
}
