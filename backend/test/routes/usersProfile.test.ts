import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';

const findUnique = vi.fn();
const update = vi.fn();
const updateMany = vi.fn();

vi.mock('../../src/lib/prisma', () => ({
  default: {
    user: {
      findUnique: (...args: unknown[]) => findUnique(...args),
      update: (...args: unknown[]) => update(...args),
    },
    deviceSession: {
      updateMany: (...args: unknown[]) => updateMany(...args),
    },
  },
}));

const bcryptCompare = vi.fn();
const bcryptHash = vi.fn();

vi.mock('bcryptjs', () => ({
  default: {
    compare: (...args: unknown[]) => bcryptCompare(...args),
    hash: (...args: unknown[]) => bcryptHash(...args),
  },
}));

vi.mock('../../src/lib/env', () => ({
  env: { JWT_SECRET: 'test-secret', GOOGLE_SERVER_CLIENT_ID: null },
}));

let currentUser: { id: string; name: string; role: string; sessionId: string } = {
  id: 'teacher-1',
  name: 'Teacher One',
  role: 'teacher',
  sessionId: 'session-1',
};

vi.mock('../../src/middlewares/auth', () => ({
  authenticate: (req: any, _res: any, next: any) => {
    req.user = currentUser;
    next();
  },
}));

import usersRoutes from '../../src/routes/users';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/users', usersRoutes);
  return app;
}

const profile = {
  id: 'teacher-1',
  name: 'Teacher One',
  email: 'teacher@example.com',
  role: 'teacher',
  photoUrl: null,
  xp: 0,
  streak: 0,
  createdAt: new Date(),
  gradeLevel: null,
  schoolBoard: null,
  weakSubjects: null,
  strongSubjects: null,
  organizationName: 'Sunrise Public School',
  orgLogoUrl: null,
  accentColor: '#7C4DFF',
};

beforeEach(() => {
  findUnique.mockReset();
  update.mockReset();
  updateMany.mockReset();
  bcryptCompare.mockReset();
  bcryptHash.mockReset();
  bcryptCompare.mockResolvedValue(true);
  bcryptHash.mockResolvedValue('hashed-new');
  currentUser = { id: 'teacher-1', name: 'Teacher One', role: 'teacher', sessionId: 'session-1' };
});

describe('PUT /api/users/profile', () => {
  it('persists org branding fields', async () => {
    update.mockResolvedValue(profile);
    const app = buildApp();
    const res = await request(app)
      .put('/api/users/profile')
      .send({ organizationName: 'Sunrise Public School', accentColor: '#7C4DFF' });
    expect(res.status).toBe(200);
    expect(update.mock.calls[0][0]).toMatchObject({
      data: { organizationName: 'Sunrise Public School', accentColor: '#7C4DFF' },
    });
    expect(res.body.organizationName).toBe('Sunrise Public School');
    expect(res.body.accentColor).toBe('#7C4DFF');
  });

  it('rejects self-promotion to admin', async () => {
    const app = buildApp();
    const res = await request(app).put('/api/users/profile').send({ role: 'admin' });
    expect(res.status).toBe(400);
    expect(update).not.toHaveBeenCalled();
  });

  it('requires the current password to change it', async () => {
    findUnique.mockResolvedValue({ id: 'teacher-1', password: 'hashed' });
    const app = buildApp();
    const res = await request(app)
      .put('/api/users/profile')
      .send({ newPassword: 'newpass123' });
    expect(res.status).toBe(401);
    expect(update).not.toHaveBeenCalled();
  });

  it('rejects a wrong current password', async () => {
    findUnique.mockResolvedValue({ id: 'teacher-1', password: 'hashed' });
    bcryptCompare.mockResolvedValue(false);
    const app = buildApp();
    const res = await request(app)
      .put('/api/users/profile')
      .send({ currentPassword: 'wrong', newPassword: 'newpass123' });
    expect(res.status).toBe(401);
    expect(update).not.toHaveBeenCalled();
  });

  it('changes the password and revokes every other device session', async () => {
    findUnique.mockResolvedValue({ id: 'teacher-1', password: 'hashed' });
    update.mockResolvedValue({ ...profile, password: undefined });
    const app = buildApp();
    const res = await request(app)
      .put('/api/users/profile')
      .send({ currentPassword: 'oldpass', newPassword: 'newpass123' });
    expect(res.status).toBe(200);
    expect(bcryptHash).toHaveBeenCalledWith('newpass123', 10);
    expect(updateMany).toHaveBeenCalledWith({
      where: { userId: 'teacher-1', revokedAt: null, id: { not: 'session-1' } },
      data: { revokedAt: expect.any(Date) },
    });
  });

  it('returns 500 when the database is down', async () => {
    update.mockRejectedValue(new Error('connection lost'));
    const app = buildApp();
    const res = await request(app)
      .put('/api/users/profile')
      .send({ name: 'Renamed' });
    expect(res.status).toBe(500);
  });
});