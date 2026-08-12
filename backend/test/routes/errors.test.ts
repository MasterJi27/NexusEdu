import { describe, it, expect } from 'vitest';
import express from 'express';
import request from 'supertest';
import errorsRoutes from '../../src/routes/errors';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/errors', errorsRoutes);
  return app;
}

describe('POST /api/errors', () => {
  it('accepts a minimal valid report and responds 204', async () => {
    const app = buildApp();
    const res = await request(app).post('/api/errors').send({ message: 'Something broke' });
    expect(res.status).toBe(204);
  });

  it('accepts the full optional field set', async () => {
    const app = buildApp();
    const res = await request(app).post('/api/errors').send({
      message: 'Null pointer in widget tree',
      stack: 'at build (main.dart:42)',
      fatal: true,
      appVersion: '1.1.0+4',
      platform: 'android',
    });
    expect(res.status).toBe(204);
  });

  it('rejects a report with no message', async () => {
    const app = buildApp();
    const res = await request(app).post('/api/errors').send({ stack: 'no message here' });
    expect(res.status).toBe(400);
  });

  it('rejects an oversized message instead of storing it unbounded', async () => {
    const app = buildApp();
    const res = await request(app)
      .post('/api/errors')
      .send({ message: 'x'.repeat(3000) });
    expect(res.status).toBe(400);
  });
});
