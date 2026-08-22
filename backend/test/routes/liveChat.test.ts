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
    liveChatMessage: { findMany: (...args: unknown[]) => findMany(...args), create: (...args: unknown[]) => create(...args) },
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

describe('GET /api/live/live/:id/messages', () => {
  it('returns the chat stream with an isTeacher flag per sender', async () => {
    findUnique.mockResolvedValue(openLive);
    findMany.mockResolvedValue([
      { id: 'm1', userId: 'teacher-1', name: 'Teacher One', message: 'Hi class', createdAt: new Date() },
      { id: 'm2', userId: 'student-1', name: 'Student One', message: 'Hello sir', createdAt: new Date() },
    ]);
    const app = buildApp();
    const res = await request(app).get('/api/live/live/live-1/messages');
    expect(res.status).toBe(200);
    expect(res.body.items[0].isTeacher).toBe(true);
    expect(res.body.items[1].isTeacher).toBe(false);
  });

  it('forwards the after cursor as a createdAt filter', async () => {
    findUnique.mockResolvedValue(openLive);
    findMany.mockResolvedValue([]);
    const app = buildApp();
    await request(app).get('/api/live/live/live-1/messages?after=1755400000000');
    expect(findMany.mock.calls[0][0]).toMatchObject({
      where: { liveSessionId: 'live-1', createdAt: { gt: new Date(1755400000000) } },
    });
  });

  it('returns 404 for a session that ended', async () => {
    findUnique.mockResolvedValue({ ...openLive, endedAt: new Date() });
    const app = buildApp();
    const res = await request(app).get('/api/live/live/live-1/messages');
    expect(res.status).toBe(404);
  });

  it('returns 404 for a student who is not enrolled', async () => {
    currentUser = { id: 'student-9', name: 'Stranger', role: 'student' };
    findUnique.mockResolvedValueOnce(openLive).mockResolvedValueOnce(null);
    const app = buildApp();
    const res = await request(app).get('/api/live/live/live-1/messages');
    expect(res.status).toBe(404);
  });
});

describe('POST /api/live/live/:id/messages', () => {
  it('creates a message with the sender name denormalized', async () => {
    findUnique.mockResolvedValueOnce(openLive).mockResolvedValueOnce({ name: 'Teacher One' });
    create.mockResolvedValue({ id: 'm3', userId: 'teacher-1', name: 'Teacher One', message: 'Question?', createdAt: new Date() });
    const app = buildApp();
    const res = await request(app).post('/api/live/live/live-1/messages').send({ message: 'Question?' });
    expect(res.status).toBe(201);
    expect(res.body.isTeacher).toBe(true);
    expect(create.mock.calls[0][0]).toMatchObject({
      data: { liveSessionId: 'live-1', userId: 'teacher-1', name: 'Teacher One', message: 'Question?' },
    });
  });

  it('rejects an empty or oversized message', async () => {
    const app = buildApp();
    const empty = await request(app).post('/api/live/live/live-1/messages').send({ message: '   ' });
    expect(empty.status).toBe(400);
    const oversized = await request(app)
      .post('/api/live/live/live-1/messages')
      .send({ message: 'x'.repeat(501) });
    expect(oversized.status).toBe(400);
    expect(create).not.toHaveBeenCalled();
  });

  it('accepts an image message (data URI) without text', async () => {
    findUnique.mockResolvedValueOnce(openLive).mockResolvedValueOnce({ name: 'Teacher One' });
    create.mockResolvedValue({
      id: 'm4', userId: 'teacher-1', name: 'Teacher One', message: '',
      imageData: 'data:image/png;base64,iVBORw0KGgo=', createdAt: new Date(),
    });
    const app = buildApp();
    const res = await request(app)
      .post('/api/live/live/live-1/messages')
      .send({ imageData: 'data:image/png;base64,iVBORw0KGgo=' });
    expect(res.status).toBe(201);
    expect(create.mock.calls[0][0]).toMatchObject({
      data: { liveSessionId: 'live-1', userId: 'teacher-1', name: 'Teacher One', message: '', imageData: 'data:image/png;base64,iVBORw0KGgo=' },
    });
  });

  it('rejects a non-image data URI and a body with neither field', async () => {
    const app = buildApp();
    const badUri = await request(app)
      .post('/api/live/live/live-1/messages')
      .send({ imageData: 'https://example.com/x.png' });
    expect(badUri.status).toBe(400);
    const neither = await request(app).post('/api/live/live/live-1/messages').send({});
    expect(neither.status).toBe(400);
    expect(create).not.toHaveBeenCalled();
  });
});