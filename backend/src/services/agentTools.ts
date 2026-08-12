import prisma from '../lib/prisma';
import { getUsageSummary } from './aiService';

/**
 * Tools exposed to the tutor agent. Each tool returns a JSON string the model
 * can reason over. Queries are scoped to the requesting user wherever the
 * data is personal; nothing sensitive (password hashes, tokens) is ever
 * exposed. All functions are read-only.
 */

export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

export const agentTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_student_profile',
      description:
        "Get the student's profile: XP, streak, grade level, school board, weak subjects and strong subjects. Use this to personalize study advice.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_attendance_summary',
      description:
        "Get the student's attendance for the last 30 days: counts of present, absent, late and leave, plus a list of missed subjects. Use this when asked about attendance or discipline in studies.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_ai_usage',
      description:
        "Get the student's AI usage today, this week and this month: number of requests and total tokens, broken down by feature (chat, tutor, math, quiz...). Use this when asked how much AI they've used.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_upcoming_assignments',
      description:
        'Get upcoming assignments with due dates and course titles. Use this when asked about homework, deadlines or what to work on next.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_teacher_notes',
      description:
        "Get titles and topics of published teacher notes available to the student's grade. Use this to point the student at relevant study material.",
      parameters: {
        type: 'object',
        properties: {
          subject: {
            type: 'string',
            description: 'Optional subject filter (e.g. Physics).',
          },
        },
      },
    },
  },
];

function safeParse(json: string): Record<string, unknown> {
  try {
    return JSON.parse(json || '{}');
  } catch {
    return {};
  }
}

async function getStudentProfile(userId: string): Promise<string> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      name: true, xp: true, streak: true, gradeLevel: true, schoolBoard: true,
      weakSubjects: true, strongSubjects: true, lastLoginAt: true,
    },
  });
  if (!user) return JSON.stringify({ error: 'Profile not found' });
  return JSON.stringify(user);
}

async function getAttendanceSummary(userId: string): Promise<string> {
  const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const records = await prisma.attendanceRecord.findMany({
    where: { studentId: userId, serverMarkedAt: { gte: since } },
    include: {
      session: {
        select: { subject: true, section: { select: { label: true } } },
      },
    },
  });
  const counts = { present: 0, absent: 0, late: 0, leave: 0 };
  const missed: string[] = [];
  for (const r of records) {
    counts[r.status as keyof typeof counts] = (counts[r.status as keyof typeof counts] ?? 0) + 1;
    if (r.status === 'absent' || r.status === 'late' || r.status === 'leave') {
      missed.push(`${r.session.subject} (${r.session.section.label})`);
    }
  }
  return JSON.stringify({ total: records.length, ...counts, missedSubjects: missed });
}

async function getAiUsage(userId: string): Promise<string> {
  const summary = await getUsageSummary(userId);
  return JSON.stringify({
    today: summary.today,
    week: summary.week,
    month: summary.month,
    byFeature: summary.byFeature,
    quota: summary.quota,
  });
}

async function getUpcomingAssignments(): Promise<string> {
  const assignments = await prisma.assignment.findMany({
    where: { dueDate: { gte: new Date() } },
    include: {
      module: {
        select: { title: true, course: { select: { title: true } } },
      },
    },
    orderBy: { dueDate: 'asc' },
    take: 10,
  });
  return JSON.stringify(
    assignments.map((a) => ({
      title: a.title,
      course: a.module.course.title,
      module: a.module.title,
      due: a.dueDate,
    })),
  );
}

async function getTeacherNotes(userId: string, args: Record<string, unknown>): Promise<string> {
  const subject = (args.subject as string) || undefined;
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { gradeLevel: true },
  });
  const notes = await prisma.teacherNote.findMany({
    where: {
      isPublished: true,
      ...(user?.gradeLevel ? { gradeLevel: user.gradeLevel } : {}),
      ...(subject ? { subject } : {}),
    },
    select: { title: true, topic: true, subject: true, gradeLevel: true },
    orderBy: { createdAt: 'desc' },
    take: 15,
  });
  return JSON.stringify(notes);
}

export async function runTool(name: string, rawArgs: string, userId: string): Promise<string> {
  const args = safeParse(rawArgs);
  try {
    switch (name) {
      case 'get_student_profile':
        return await getStudentProfile(userId);
      case 'get_attendance_summary':
        return await getAttendanceSummary(userId);
      case 'get_ai_usage':
        return await getAiUsage(userId);
      case 'get_upcoming_assignments':
        return await getUpcomingAssignments();
      case 'get_teacher_notes':
        return await getTeacherNotes(userId, args);
      default:
        return JSON.stringify({ error: `Unknown tool: ${name}` });
    }
  } catch (error) {
    console.error(`Tool ${name} failed:`, error);
    return JSON.stringify({ error: `Tool ${name} failed` });
  }
}
