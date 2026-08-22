import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';

const findUnique = vi.fn();
const findMany = vi.fn();
const count = vi.fn();
const create = vi.fn();
const update = vi.fn();
const updateMany = vi.fn();

vi.mock('../../src/lib/prisma', () => ({
  default: {
    user: {
      findUnique: (...args: unknown[]) => findUnique(...args),
      update: (...args: unknown[]) => update(...args),
    },
    deviceSession: {
      findUnique: (...args: unknown[]) => findUnique(...args),
      findMany: (...args: unknown[]) => findMany(...args),
      count: (...args: unknown[]) => count(...args),
      create: (...args: unknown[]) => create(...args),
      update: (...args: unknown[]) => update(...args),
      updateMany: (...args: unknown[]) => updateMany(...args),
    },
    loginLog: { create: (...args: unknown[]) => create(...args) },
    activityLog: { create: (...args: unknown[]) => create(...args) },
    $transaction: vi.fn(async (arg: any) => {
      if (Array.isArray(arg)) return Promise.all(arg);
      if (typeof arg === 'function') {
        return arg({
          user: {
            findUnique: (...a: unknown[]) => findUnique(...a),
            update: (...a: unknown[]) => update(...a),
          },
          deviceSession: {
            findUnique: (...a: unknown[]) => findUnique(...a),
            findMany: (...a: unknown[]) => findMany(...a),
            count: (...a: unknown[]) => count(...a),
            create: (...a: unknown[]) => create(...a),
            update: (...a: unknown[]) => update(...a),
            updateMany: (...a: unknown[]) => updateMany(...a),
          },
        });
      }
      return arg;
    }),
  },
}));

vi.mock('bcryptjs', () => ({
  default: {
    compare: vi.fn().mockResolvedValue(true),
    hash: vi.fn().mockResolvedValue('hashed'),
  },
}));

// Keep the real limiter out: it shares in-memory state across tests in this
// file and would turn a cap test into a rate-limit test.
vi.mock('../../src/lib/env', () => ({
  env: { JWT_SECRET: 'test-secret', GOOGLE_SERVER_CLIENT_ID: null },
}));

import authRoutes from '../../src/routes/auth';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/auth', authRoutes);
  return app;
}

const user = {
  id: 'student-1',
  name: 'Student One',
  email: 'student@example.com',
  password: 'hashed',
  role: 'student',
};

beforeEach(() => {
  findUnique.mockReset();
  findMany.mockReset();
  count.mockReset();
  create.mockReset();
  update.mockReset();
  updateMany.mockReset();
});

describe('device account cap (MAX_ACCOUNTS_PER_DEVICE = 3)', () => {
  it('blocks login on a device already linked to 3 accounts', async () => {
    findUnique
      .mockResolvedValueOnce(user)
      .mockResolvedValueOnce(null);
    count.mockResolvedValue(3);
    const app = buildApp();
    const res = await request(app)
      .post('/api/auth/login')
      .set('X-Device-Id', 'shared-phone')
      .send({ email: 'student@example.com', password: 'whatever' });
    expect(res.status).toBe(403);
    expect(res.body.error).toContain('already linked to 3 accounts');
    expect(create).not.toHaveBeenCalled();
  });

  it('allows a fresh account when the device has room', async () => {
    findUnique
      .mockResolvedValueOnce(user)
      .mockResolvedValueOnce(null);
    count.mockResolvedValue(2);
    findMany.mockResolvedValue([]);
    create.mockResolvedValue({ id: 'session-1' });
    const app = buildApp();
    const res = await request(app)
      .post('/api/auth/login')
      .set('X-Device-Id', 'family-phone')
      .send({ email: 'student@example.com', password: 'whatever' });
    expect(res.status).toBe(200);
    expect(create).toHaveBeenCalled();
  });

  it('re-signing in an already-linked account bypasses the cap', async () => {
    findUnique
      .mockResolvedValueOnce(user)
      .mockResolvedValueOnce({ id: 'existing-session' });
    update.mockResolvedValue({ id: 'existing-session' });
    const app = buildApp();
    const res = await request(app)
      .post('/api/auth/login')
      .set('X-Device-Id', 'shared-phone')
      .send({ email: 'student@example.com', password: 'whatever' });
    expect(res.status).toBe(200);
    expect(count).not.toHaveBeenCalled();
    expect(update).toHaveBeenCalled();
  });
});

describe('pre-login device revoke (device-limit recovery)', () => {
  it('revokes a device session after verifying the email owns it', async () => {
    findUnique.mockResolvedValueOnce({ id: 'student-1' });
    updateMany.mockResolvedValueOnce({ count: 1 });
    const app = buildApp();
    const res = await request(app)
      .post('/api/auth/device-sessions/revoke')
      .send({ email: 'student@example.com', sessionId: 'stale-session' });
    expect(res.status).toBe(204);
    const where = updateMany.mock.calls[0][0].where;
    expect(where.userId).toBe('student-1');
    expect(where.id).toBe('stale-session');
    expect(where.revokedAt).toBeNull();
  });

  it('returns 404 for an unknown email', async () => {
    findUnique.mockResolvedValueOnce(null);
    const app = buildApp();
    const res = await request(app)
      .post('/api/auth/device-sessions/revoke')
      .send({ email: 'nobody@example.com', sessionId: 'stale-session' });
    expect(res.status).toBe(404);
    expect(updateMany).not.toHaveBeenCalled();
  });

  it('returns 404 when the session is already gone', async () => {
    findUnique.mockResolvedValueOnce({ id: 'student-1' });
    updateMany.mockResolvedValueOnce({ count: 0 });
    const app = buildApp();
    const res = await request(app)
      .post('/api/auth/device-sessions/revoke')
      .send({ email: 'student@example.com', sessionId: 'stale-session' });
    expect(res.status).toBe(404);
  });
});
