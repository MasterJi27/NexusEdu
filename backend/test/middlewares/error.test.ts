import { describe, it, expect, vi } from 'vitest';
import { requireRole, isOwnerOrAdmin, securityHeaders, notFound, errorHandler } from '../../src/middlewares/error';

function mockRes() {
  const res: any = {
    headersSent: false,
    setHeader: vi.fn(),
  };
  res.status = vi.fn().mockReturnValue(res);
  res.json = vi.fn().mockReturnValue(res);
  return res;
}

describe('requireRole', () => {
  it('responds 401 when there is no authenticated user', () => {
    const req: any = { user: undefined };
    const res = mockRes();
    const next = vi.fn();
    requireRole('teacher')(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("responds 403 when the user's role isn't in the allowed list", () => {
    const req: any = { user: { id: 'u1', role: 'student' } };
    const res = mockRes();
    const next = vi.fn();
    requireRole('teacher', 'admin')(req, res, next);
    expect(res.status).toHaveBeenCalledWith(403);
    expect(next).not.toHaveBeenCalled();
  });

  it('calls next() when the role matches', () => {
    const req: any = { user: { id: 'u1', role: 'teacher' } };
    const res = mockRes();
    const next = vi.fn();
    requireRole('teacher', 'admin')(req, res, next);
    expect(next).toHaveBeenCalledOnce();
    expect(res.status).not.toHaveBeenCalled();
  });
});

describe('isOwnerOrAdmin', () => {
  it('is true for the resource owner', () => {
    expect(isOwnerOrAdmin('u1', { id: 'u1', role: 'student' } as any)).toBe(true);
  });
  it('is true for an admin regardless of ownership', () => {
    expect(isOwnerOrAdmin('someone-else', { id: 'u1', role: 'admin' } as any)).toBe(true);
  });
  it('is false for a non-owner, non-admin', () => {
    expect(isOwnerOrAdmin('someone-else', { id: 'u1', role: 'student' } as any)).toBe(false);
  });
  it('is false with no authenticated user', () => {
    expect(isOwnerOrAdmin('u1', undefined)).toBe(false);
  });
});

describe('securityHeaders', () => {
  it('sets the expected header set and calls next()', () => {
    const res = mockRes();
    const next = vi.fn();
    securityHeaders({} as any, res, next);
    expect(res.setHeader).toHaveBeenCalledWith('X-Content-Type-Options', 'nosniff');
    expect(res.setHeader).toHaveBeenCalledWith('X-Frame-Options', 'DENY');
    expect(next).toHaveBeenCalledOnce();
  });
});

describe('notFound', () => {
  it('responds 404 naming the missing route', () => {
    const req: any = { method: 'GET', path: '/api/nonexistent' };
    const res = mockRes();
    notFound(req, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: expect.stringContaining('/api/nonexistent') }),
    );
  });
});

describe('errorHandler', () => {
  it('responds 500 with a generic message, never the raw error', () => {
    const res = mockRes();
    const next = vi.fn();
    errorHandler(new Error('sensitive stack trace details'), {} as any, res, next);
    expect(res.status).toHaveBeenCalledWith(500);
    const body = (res.json as any).mock.calls[0][0];
    expect(body.error).toBe('Internal server error');
    expect(JSON.stringify(body)).not.toContain('sensitive stack trace');
  });

  it('delegates to next(error) instead of double-sending if headers are already sent', () => {
    const res = mockRes();
    res.headersSent = true;
    const next = vi.fn();
    const error = new Error('boom');
    errorHandler(error, {} as any, res, next);
    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith(error);
  });
});
