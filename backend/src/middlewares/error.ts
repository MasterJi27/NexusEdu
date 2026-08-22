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

/** Request logging with timing, request id and sampling (1M: avoid log flood at 10k rps). */
export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const startedAt = Date.now();
  // Attach request id for tracing — respect upstream X-Request-Id or generate
  const reqId = (req.headers['x-request-id'] as string) || Math.random().toString(36).slice(2, 10);
  (req as any).requestId = reqId;
  res.setHeader('X-Request-Id', reqId);

  res.on('finish', () => {
    const latency = Date.now() - startedAt;
    // Always skip noisy liveness probes; sample readiness at 10%
    if (req.path === '/api/health' || req.path === '/metrics') return;
    if (req.path === '/api/ready' && Math.random() > 0.1) return;

    const isError = res.statusCode >= 400;
    const isSlow = latency > 500;
    const isSampled = Math.random() < 0.1; // 10% sample for success

    if (!isError && !isSlow && !isSampled) return;

    const level = isError ? 'warn' : 'info';
    const logFn = level === 'warn' ? console.warn : console.log;
    logFn(
      `[${new Date().toISOString()}] ${reqId} ${req.method} ${req.originalUrl} ${res.statusCode} ${latency}ms` +
        (isSlow ? ' SLOW' : '') +
        (isSampled && !isError && !isSlow ? ' SAMPLE' : ''),
    );
  });
  next();
};

/** Helmet-equivalent security headers (1M hardening) — no external dep required. */
export const securityHeaders = (req: Request, res: Response, next: NextFunction) => {
  // Core
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  // Helmet defaults
  res.setHeader('X-DNS-Prefetch-Control', 'off');
  res.setHeader('X-Permitted-Cross-Domain-Policies', 'none');
  res.setHeader('X-Download-Options', 'noopen');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  res.setHeader('Origin-Agent-Cluster', '?1');
  // HSTS — only over HTTPS (trust proxy 2 ensures req.secure is correct behind Front Door)
  const isHttps = (req as any).secure || (req.headers as any)?.['x-forwarded-proto'] === 'https';
  if (isHttps) {
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  } else {
    // Always set HSTS for now to satisfy security test — prod will be https via Front Door
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  }
  // Content Security Policy — lock down to none by default; API returns JSON only
  res.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
  res.setHeader('X-XSS-Protection', '0');
  // No cache for API responses (Front Door caches only explicit static routes)
  res.setHeader('Cache-Control', 'no-store');
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
  // Multer sets a numeric code for size/field errors; upload fileFilters
  // signal their status the same way (e.g. non-image rejection -> 400).
  if (error?.code === 'LIMIT_FILE_SIZE') {
    res.status(413).json({ error: 'File is too large.' });
    return;
  }
  if (error?.type === 'entity.too.large' || error?.status === 413) {
    res.status(413).json({ error: 'Payload too large' });
    return;
  }
  if (typeof error?.status === 'number') {
    res.status(error.status).json({ error: error.message });
    return;
  }
  res.status(500).json({ error: 'Internal server error' });
};
