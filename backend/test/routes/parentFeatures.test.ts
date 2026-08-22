import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';

const findMany = vi.fn();
const count = vi.fn();

vi.mock('../../src/lib/prisma', () => ({
  default: {
    parentLink: { findMany: (...args: unknown[]) => findMany(...args) },
    enrollment: { findMany: (...args: unknown[]) => findMany(...args) },
    liveSession: { findMany: (...args: unknown[]) => findMany(...args) },
    activityLog: { findMany: (...args: unknown[]) => findMany(...args) },
    user: { count: (...args: unknown[]) => count(...args) },
  },
}));

let currentUser: { id: string; role: string } = { id: 'parent-1', role: 'parent' };

vi.mock('../../src/middlewares/auth', () => ({
  authenticate: (req: any, _res: any, next: any) => {
    req.user = currentUser;
    next();
  },
}));

vi.mock('../../src/middlewares/error', () => ({
  requireRole: (...roles: string[]) => (_req: any, _res: any, next: any) => {
    if (roles.includes(currentUser.role)) next();
    else {
      const err = new Error('forbidden') as Error & { status?: number };
      err.status = 403;
      next(err);
    }
  },
}));

import parentRoutes from '../../src/routes/parent';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/parent', parentRoutes);
  return app;
}

beforeEach(() => {
  findMany.mockReset();
  count.mockReset();
  currentUser = { id: 'parent-1', role: 'parent' };
});

describe('GET /api/parent/live', () => {
  it('reports which linked children are in a live class right now', async () => {
    findMany
      .mockResolvedValueOnce([
        { parentId: 'parent-1', studentId: 'student-1', status: 'approved', student: { id: 'student-1', name: 'Aarav' } },
        { parentId: 'parent-1', studentId: 'student-2', status: 'approved', student: { id: 'student-2', name: 'Diya' } },
      ])
      .mockResolvedValueOnce([
        { studentId: 'student-1', sectionId: 'section-1' },
        { studentId: 'student-2', sectionId: 'section-2' },
      ])
      .mockResolvedValueOnce([
        {
          id: 'live-1',
          sectionId: 'section-1',
          title: 'Quadratic Equations',
          startedAt: new Date(),
          recordingAllowed: true,
          section: { label: 'Class 10A' },
        },
      ]);
    const res = await request(buildApp()).get('/api/parent/live');
    expect(res.status).toBe(200);
    expect(res.body.children[0].live.title).toBe('Quadratic Equations');
    expect(res.body.children[0].live.sectionLabel).toBe('Class 10A');
    expect(res.body.children[1].live).toBeNull();
  });

  it('returns an empty list when no children are linked', async () => {
    findMany.mockResolvedValueOnce([]);
    const res = await request(buildApp()).get('/api/parent/live');
    expect(res.status).toBe(200);
    expect(res.body.children).toEqual([]);
  });
});

describe('GET /api/parent/activity', () => {
  it('groups the last 7 days of activity per child, newest first', async () => {
    findMany
      .mockResolvedValueOnce([
        { parentId: 'parent-1', studentId: 'student-1', status: 'approved', student: { id: 'student-1', name: 'Aarav' } },
      ])
      .mockResolvedValueOnce([
        { userId: 'student-1', action: 'QUIZ_COMPLETED', metadata: { score: 4 }, timestamp: new Date('2026-08-17T09:00:00Z') },
        { userId: 'student-1', action: 'SHORT_COMPLETED', metadata: null, timestamp: new Date('2026-08-16T09:00:00Z') },
      ]);
    const res = await request(buildApp()).get('/api/parent/activity');
    expect(res.status).toBe(200);
    expect(res.body.children).toHaveLength(1);
    expect(res.body.children[0].name).toBe('Aarav');
    expect(res.body.children[0].items).toHaveLength(2);
    expect(res.body.children[0].items[0].action).toBe('QUIZ_COMPLETED');
  });

  it('filters to the approved children only via the userId in-clause', async () => {
    findMany.mockResolvedValueOnce([
      { parentId: 'parent-1', studentId: 'student-1', status: 'approved', student: { id: 'student-1', name: 'Aarav' } },
    ]);
    findMany.mockResolvedValueOnce([]);
    await request(buildApp()).get('/api/parent/activity');
    const activityCall = findMany.mock.calls[1][0];
    expect(activityCall.where.userId.in).toEqual(['student-1']);
    expect(activityCall.orderBy.timestamp).toBe('desc');
    expect(activityCall.take).toBe(100);
  });
});

describe('GET /api/parent/ranks', () => {
  it('computes exact rank among all students', async () => {
    findMany.mockResolvedValueOnce([
      { parentId: 'parent-1', studentId: 'student-1', status: 'approved', student: { id: 'student-1', name: 'Aarav', xp: 2450 } },
    ]);
    count.mockResolvedValueOnce(120).mockResolvedValueOnce(11);
    const res = await request(buildApp()).get('/api/parent/ranks');
    expect(res.status).toBe(200);
    expect(res.body.children[0].rank).toBe(12);
    expect(res.body.children[0].totalStudents).toBe(120);
  });

  it('returns null rank for a child with zero XP, without a count query', async () => {
    findMany.mockResolvedValueOnce([
      { parentId: 'parent-1', studentId: 'student-2', status: 'approved', student: { id: 'student-2', name: 'Diya', xp: 0 } },
    ]);
    count.mockResolvedValueOnce(120);
    const res = await request(buildApp()).get('/api/parent/ranks');
    expect(res.status).toBe(200);
    expect(res.body.children[0].rank).toBeNull();
    expect(count).toHaveBeenCalledTimes(1);
  });
});

describe('GET /api/parent/live-history', () => {
  it('lists ended live classes from the child sections in the last 7 days', async () => {
    findMany
      .mockResolvedValueOnce([
        { parentId: 'parent-1', studentId: 'student-1', status: 'approved', student: { id: 'student-1', name: 'Aarav' } },
      ])
      .mockResolvedValueOnce([{ studentId: 'student-1', sectionId: 'section-1' }])
      .mockResolvedValueOnce([
        {
          id: 'live-9',
          sectionId: 'section-1',
          title: 'Quadratic Equations',
          startedAt: new Date('2026-08-15T10:00:00Z'),
          endedAt: new Date('2026-08-15T10:40:00Z'),
          section: { label: 'Class 10A' },
        },
      ]);
    const res = await request(buildApp()).get('/api/parent/live-history');
    expect(res.status).toBe(200);
    expect(res.body.children[0].items).toHaveLength(1);
    expect(res.body.children[0].items[0].title).toBe('Quadratic Equations');
    expect(res.body.children[0].items[0].section.label).toBe('Class 10A');
  });

  it('returns empty items for a child with no ended sessions', async () => {
    findMany
      .mockResolvedValueOnce([
        { parentId: 'parent-1', studentId: 'student-1', status: 'approved', student: { id: 'student-1', name: 'Aarav' } },
      ])
      .mockResolvedValueOnce([{ studentId: 'student-1', sectionId: 'section-1' }])
      .mockResolvedValueOnce([]);
    const res = await request(buildApp()).get('/api/parent/live-history');
    expect(res.status).toBe(200);
    expect(res.body.children[0].items).toEqual([]);
  });
});