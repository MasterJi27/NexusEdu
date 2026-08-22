import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import {
  signup,
  login,
  googleLogin,
  logout,
  listSessions,
  revokeSession,
  revokeDeviceSessionPreLogin,
  forgotPassword,
  resetPassword,
} from '../controllers/auth';
import { authenticate } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import { ipKey, getRateLimitStore } from '../middlewares/rateLimit.js';

const router = Router();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 login requests per `window` (here, per 15 minutes)
  message: { error: 'Too many login attempts from this IP, please try again after 15 minutes' },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  store: getRateLimitStore('rl:auth:login:') as any,
  keyGenerator: ipKey,
});

// Signup is the account-farming vector (spam accounts, storage abuse), so it
// gets its own tighter window than login: 10 new accounts per IP per hour is
// far above any real classroom's needs and far below a spam script's.
const signupLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10,
  message: { error: 'Too many accounts created from this IP. Try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
  store: getRateLimitStore('rl:auth:signup:') as any,
  keyGenerator: ipKey,
});

// The account role is chosen at signup and is permanent: it can never be
// changed later via the profile endpoint, so each login lands on the right
// dashboard and no account can masquerade as another role.
const signupSchema = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(6).max(200),
  role: z.enum(['student', 'teacher', 'parent', 'admin']).optional(),
  deviceId: z.string().trim().min(1).max(120).optional(),
  deviceName: z.string().trim().min(1).max(120).optional(),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
  deviceId: z.string().trim().min(1).max(120).optional(),
  deviceName: z.string().trim().min(1).max(120).optional(),
});

const googleLoginSchema = z.object({
  idToken: z.string().min(1),
  deviceId: z.string().trim().min(1).max(120).optional(),
  deviceName: z.string().trim().min(1).max(120).optional(),
});

const forgotPasswordSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
});

const resetPasswordSchema = z.object({
  token: z.string().min(16).max(200),
  newPassword: z.string().min(6).max(200),
});

// Recovery for the device-limit lockout: the user has no token (login keeps
// failing), so this pre-login revoke gets its own limiter like login does.
const revokeDeviceLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many attempts. Please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
  store: getRateLimitStore('rl:auth:revoke:') as any,
  keyGenerator: ipKey,
});

const revokeDeviceSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  sessionId: z.string().trim().min(1).max(120),
});

router.post('/signup', signupLimiter, validateBody(signupSchema), signup);
router.post('/login', loginLimiter, validateBody(loginSchema), login);
router.post('/google', loginLimiter, validateBody(googleLoginSchema), googleLogin);
router.post('/forgot-password', loginLimiter, validateBody(forgotPasswordSchema), forgotPassword);
router.post('/reset-password', loginLimiter, validateBody(resetPasswordSchema), resetPassword);
router.post('/logout', authenticate, logout);
router.get('/sessions', authenticate, listSessions);
router.delete('/sessions/:id', authenticate, revokeSession);
router.post(
  '/device-sessions/revoke',
  revokeDeviceLimiter,
  validateBody(revokeDeviceSchema),
  revokeDeviceSessionPreLogin,
);

export default router;
