import { Request, Response, NextFunction } from 'express';
import { AuthRequest } from './auth';

export type Role = 'student' | 'teacher' | 'parent' | 'admin';

/**
 * Guard for role-protected routes. Usage: router.post('/', requireRole('teacher', 'admin'), handler)
 * Responds 401 when unauthenticated and 403 when the role doesn't match.
 */
export const requireRole = (...roles: Role[]) =>
  (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    if (!roles.includes(req.user.role as Role)) {
      res.status(403).json({ error: `This action requires role: ${roles.join(' or ')}` });
      return;
    }
    next();
  };

/**
 * Ownership check for a "delete your own X, unless you're an admin" guard.
 * Not route middleware like requireRole — ownership isn't known until the
 * resource has been fetched, so this runs inline inside the handler instead.
 */
export const isOwnerOrAdmin = (ownerId: string, user: AuthRequest['user']): boolean =>
  user?.role === 'admin' || ownerId === user?.id;

/** Request logging with timing + request id for tracing in production. */
export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const startedAt = Date.now();
  res.on('finish', () => {
    const latency = Date.now() - startedAt;
    if (req.path === '/api/health') return;
    console.log(
      `[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ${res.statusCode} ${latency}ms`,
    );
  });
  next();
};

/** Minimal security headers without pulling in helmet. */
export const securityHeaders = (req: Request, res: Response, next: NextFunction) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  next();
};

/** Catch-all for unknown routes. */
export const notFound = (req: Request, res: Response) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
};

/** Central error handler — keeps responses consistent and never leaks stacks. */
export const errorHandler = (error: any, req: Request, res: Response, next: NextFunction) => {
  console.error('Unhandled error:', error);
  if (res.headersSent) {
    next(error);
    return;
  }
  res.status(500).json({ error: 'Internal server error' });
};
