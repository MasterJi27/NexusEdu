import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';

const count = vi.fn();
const findFirst = vi.fn();
const findMany = vi.fn();
const findUnique = vi.fn();

vi.mock('../../src/lib/prisma', () => ({
  default: {
    section: { count: (...args: unknown[]) => count(...args), findMany: (...args: unknown[]) => findMany(...args) },
    teacherNote: { count: (...args: unknown[]) => count(...args) },
    notification: { count: (...args: unknown[]) => count(...args) },
    liveSession: { findFirst: (...args: unknown[]) => findFirst(...args), findMany: (...args: unknown[]) => findMany(...args) },
    user: { findUnique: (...args: unknown[]) => findUnique(...args) },
  },
}));

let currentUser: { id: string; role: string } = { id: 'teacher-1', role: 'teacher' };

vi.mock('../../src/middlewares/auth', () => ({
  authenticate: (req: any, _res: any, next: any) => {
    req.user = currentUser;
    next();
  },
  requireRole: (...roles: string[]) => (req: any, res: any, next: any) => {
    if (!roles.includes(req.user?.role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  },
}));

import classroomRoutes from '../../src/routes/classroom';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/classroom', classroomRoutes);
  return app;
}

beforeEach(() => {
  count.mockReset();
  findFirst.mockReset();
  findMany.mockReset();
  findUnique.mockReset();
  currentUser = { id: 'teacher-1', role: 'teacher' };
});

describe('GET /api/classroom/teacher/home', () => {
  it('aggregates counts, live-now and recent lists in one round trip', async () => {
    count
      .mockResolvedValueOnce(4) // sectionCount
      .mockResolvedValueOnce(5) // noteCount
      .mockResolvedValueOnce(2); // unreadCount
    findFirst.mockResolvedValue({
      id: 'live-1',
      title: 'Newton\'s laws',
      recordingAllowed: true,
      startedAt: new Date(),
      section: { label: 'Class 10-B' },
    });
    findMany.mockImplementation(async (args: any) => {
      if (args?.include?._count) {
        return [
          { id: 's1', label: 'Class 10-B', gradeLevel: 'Class 10', subject: 'Physics', _count: { enrollments: 30 } },
          { id: 's2', label: 'Class 11-A', gradeLevel: 'Class 11', subject: 'Maths', _count: { enrollments: 25 } },
        ];
      }
      return [{ id: 'live-9', title: 'Earlier class', startedAt: new Date(), endedAt: new Date(), section: { label: 'Class 10-B' } }];
    });
    findUnique.mockResolvedValue({
      name: 'Teacher One',
      organizationName: 'Sunrise Public School',
      orgLogoUrl: 'https://blob.example/org-logos/x.png',
      accentColor: '#4F46E5',
    });

    const app = buildApp();
    const res = await request(app).get('/api/classroom/teacher/home');
    expect(res.status).toBe(200);
    expect(res.body.sectionCount).toBe(4);
    expect(res.body.studentCount).toBe(55);
    expect(res.body.noteCount).toBe(5);
    expect(res.body.unreadCount).toBe(2);
    expect(res.body.liveNow).toMatchObject({ id: 'live-1', sectionLabel: 'Class 10-B' });
    expect(res.body.recentSections).toHaveLength(2);
    expect(res.body.recentLive).toHaveLength(1);
  });

  it('returns the org branding for watermarks and themes', async () => {
    count.mockResolvedValue(0);
    findFirst.mockResolvedValue(null);
    findMany.mockResolvedValue([]);
    findUnique.mockResolvedValue({
      name: 'Teacher One',
      organizationName: 'Sunrise Public School',
      orgLogoUrl: 'https://blob.example/org-logos/x.png',
      accentColor: '#4F46E5',
    });
    const app = buildApp();
    const res = await request(app).get('/api/classroom/teacher/home');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      teacherName: 'Teacher One',
      organizationName: 'Sunrise Public School',
      orgLogoUrl: 'https://blob.example/org-logos/x.png',
      accentColor: '#4F46E5',
    });
  });

  it('rejects students', async () => {
    currentUser = { id: 'student-1', role: 'student' };
    const app = buildApp();
    const res = await request(app).get('/api/classroom/teacher/home');
    expect(res.status).toBe(403);
  });
});
