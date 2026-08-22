import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';

const findUnique = vi.fn();
const findMany = vi.fn();
const create = vi.fn();

vi.mock('../../src/lib/prisma', () => ({
  default: {
    liveSession: { findUnique: (...args: unknown[]) => findUnique(...args) },
    enrollment: { findUnique: (...args: unknown[]) => findUnique(...args) },
    user: { findUnique: (...args: unknown[]) => findUnique(...args) },
    liveBoardEvent: {
      findMany: (...args: unknown[]) => findMany(...args),
      create: (...args: unknown[]) => create(...args),
    },
  },
}));

let currentUser: { id: string; name: string; role: string } = {
  id: 'teacher-1',
  name: 'Teacher One',
  role: 'teacher',
};

vi.mock('../../src/middlewares/auth', () => ({
  authenticate: (req: any, _res: any, next: any) => {
    req.user = currentUser;
    next();
  },
}));

import liveClassRoutes from '../../src/routes/liveClass';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/live', liveClassRoutes);
  return app;
}

const openLive = { id: 'live-1', sectionId: 'section-1', teacherId: 'teacher-1', endedAt: null };

beforeEach(() => {
  findUnique.mockReset();
  findMany.mockReset();
  create.mockReset();
  currentUser = { id: 'teacher-1', name: 'Teacher One', role: 'teacher' };
});

describe('GET /api/live/live/:id/board/events', () => {
  it('returns newer events only, ordered by seq, with the nextSeq cursor', async () => {
    findUnique.mockResolvedValue(openLive);
    findMany.mockResolvedValue([
      { seq: 3, type: 'stroke', payload: { color: 4294967295, width: 4, points: [[0.1, 0.2]] } },
      { seq: 4, type: 'clear', payload: {} },
    ]);
    const app = buildApp();
    const res = await request(app).get('/api/live/live/live-1/board/events?after=2');
    expect(res.status).toBe(200);
    expect(res.body.nextSeq).toBe(4);
    expect(findMany.mock.calls[0][0]).toMatchObject({
      where: { liveSessionId: 'live-1', seq: { gt: 2 } },
      orderBy: { seq: 'asc' },
      take: 100,
    });
  });

  it('defaults the cursor to 0 when missing or malformed', async () => {
    findUnique.mockResolvedValue(openLive);
    findMany.mockResolvedValue([]);
    const app = buildApp();
    await request(app).get('/api/live/live/live-1/board/events');
    await request(app).get('/api/live/live/live-1/board/events?after=abc');
    expect(findMany.mock.calls[0][0]).toMatchObject({ where: { seq: { gt: 0 } } });
    expect(findMany.mock.calls[1][0]).toMatchObject({ where: { seq: { gt: 0 } } });
  });

  it('returns 404 for a student who is not enrolled', async () => {
    currentUser = { id: 'student-9', name: 'Stranger', role: 'student' };
    findUnique.mockResolvedValueOnce(openLive).mockResolvedValueOnce(null);
    const app = buildApp();
    const res = await request(app).get('/api/live/live/live-1/board/events');
    expect(res.status).toBe(404);
  });
});

describe('POST /api/live/live/:id/board/events', () => {
  it('lets the teacher append a stroke event', async () => {
    findUnique.mockResolvedValue(openLive);
    create.mockResolvedValue({ seq: 5, type: 'stroke', payload: { color: 4278255360, width: 4, points: [[0.5, 0.5]] } });
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/board/events')
      .send({ type: 'stroke', payload: { color: 4278255360, width: 4, points: [[0.5, 0.5]] } });
    expect(res.status).toBe(201);
    expect(create.mock.calls[0][0]).toMatchObject({
      data: { liveSessionId: 'live-1', type: 'stroke', payload: { color: 4278255360, width: 4, points: [[0.5, 0.5]] } },
    });
  });

  it('lets the teacher append a clear event', async () => {
    findUnique.mockResolvedValue(openLive);
    create.mockResolvedValue({ seq: 6, type: 'clear', payload: {} });
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/board/events')
      .send({ type: 'clear', payload: {} });
    expect(res.status).toBe(201);
    expect(create.mock.calls[0][0]).toMatchObject({ data: { type: 'clear' } });
  });

  it('blocks students from writing board events', async () => {
    currentUser = { id: 'student-1', name: 'Student One', role: 'student' };
    findUnique.mockResolvedValue(openLive);
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/board/events')
      .send({ type: 'stroke', payload: { color: 1, width: 4, points: [[0.5, 0.5]] } });
    expect(res.status).toBe(403);
    expect(create).not.toHaveBeenCalled();
  });

  it('rejects a stroke without color or points', async () => {
    findUnique.mockResolvedValue(openLive);
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/board/events')
      .send({ type: 'stroke', payload: { width: 4 } });
    expect(res.status).toBe(400);
    expect(create).not.toHaveBeenCalled();
  });

  it('rejects points outside the normalized 0..1 range', async () => {
    findUnique.mockResolvedValue(openLive);
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/board/events')
      .send({ type: 'stroke', payload: { color: 1, width: 4, points: [[0.5, 1.5]] } });
    expect(res.status).toBe(400);
  });

  it('returns 404 for a session that ended', async () => {
    findUnique.mockResolvedValue({ ...openLive, endedAt: new Date() });
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/board/events')
      .send({ type: 'clear', payload: {} });
    expect(res.status).toBe(404);
  });
});