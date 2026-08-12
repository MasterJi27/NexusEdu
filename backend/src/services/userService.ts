import prisma from '../lib/prisma';

/**
 * Looks up a student account by email. Shared by the two flows that take a
 * student's email as input rather than an id — a teacher enrolling a student
 * into a section, and a parent requesting a link to their child — so both
 * apply the same "must exist and must actually be a student" rule.
 */
export async function findStudentByEmail(email: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  return user && user.role === 'student' ? user : null;
}
