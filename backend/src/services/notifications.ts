import prisma from '../lib/prisma';
import { getNotificationQueue } from '../lib/queue';

/**
 * In-app notification fan-out to every student enrolled in a section.
 * Shared by syllabus posts, class tasks and live-class starts so the
 * notification stream always behaves the same way: one row per student,
 * none when the section is empty.
 *
 * When Redis/BullMQ is available, fan-out is enqueued async via BullMQ
 * and returns immediately; a worker processes the job. Otherwise falls
 * back to direct createMany (synchronous).
 */
export async function notifySection(
  section: { id: string; label: string },
  type: string,
  title: string,
  body: string,
  link: string,
) {
  // Try async via BullMQ when available
  try {
    const queue = await getNotificationQueue();
    if (queue) {
      await queue.add('notifySection', { sectionId: section.id, payload: { type, title, body, link } });
      return;
    }
  } catch (err) {
    console.error('[notifications] queue add failed, falling back to direct DB:', err);
  }

  const enrollments = await prisma.enrollment.findMany({
    where: { sectionId: section.id },
    select: { studentId: true },
  });
  if (enrollments.length === 0) return;
  await prisma.notification.createMany({
    data: enrollments.map((e) => ({
      userId: e.studentId,
      type,
      title,
      body,
      link,
    })),
  });
}