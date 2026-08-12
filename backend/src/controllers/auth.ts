import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import prisma from '../lib/prisma';
import { logLogin, logActivity } from '../lib/logger';
import { env } from '../lib/env';
import { AuthRequest } from '../middlewares/auth';

const JWT_SECRET = env.JWT_SECRET;
const googleClient = env.GOOGLE_SERVER_CLIENT_ID ? new OAuth2Client(env.GOOGLE_SERVER_CLIENT_ID) : null;
const MAX_ACTIVE_DEVICE_SESSIONS = Number(process.env.MAX_ACTIVE_DEVICE_SESSIONS || 2);

function publicUser<T extends { password?: string | null }>(user: T) {
  const { password, ...safe } = user;
  return safe;
}

function getRequestIp(req: Request): string | undefined {
  return req.ip || req.socket.remoteAddress || undefined;
}

function getDeviceMetadata(req: Request) {
  const userAgent = req.headers['user-agent']?.toString() || 'unknown';
  const rawDeviceId = (req.body.deviceId || req.headers['x-device-id'])?.toString().trim();
  const deviceId = rawDeviceId && rawDeviceId.length <= 120
    ? rawDeviceId
    : `ua-${crypto.createHash('sha256').update(userAgent).digest('hex').slice(0, 32)}`;
  const rawDeviceName = (req.body.deviceName || req.headers['x-device-name'])?.toString().trim();
  const deviceName = rawDeviceName && rawDeviceName.length <= 120
    ? rawDeviceName
    : userAgent.slice(0, 120);

  return {
    deviceId,
    deviceName,
    userAgent: userAgent.slice(0, 500),
    ipAddress: getRequestIp(req),
  };
}

async function createOrRefreshDeviceSession(req: Request, userId: string) {
  const metadata = getDeviceMetadata(req);
  const existing = await prisma.deviceSession.findUnique({
    where: {
      userId_deviceId: {
        userId,
        deviceId: metadata.deviceId,
      },
    },
  });

  if (existing) {
    return prisma.deviceSession.update({
      where: { id: existing.id },
      data: {
        ...metadata,
        revokedAt: null,
        lastSeenAt: new Date(),
      },
    });
  }

  const activeSessions = await prisma.deviceSession.findMany({
    where: { userId, revokedAt: null },
    orderBy: { lastSeenAt: 'desc' },
    select: { id: true, deviceName: true, lastSeenAt: true, createdAt: true },
  });

  if (activeSessions.length >= MAX_ACTIVE_DEVICE_SESSIONS) {
    return {
      error: 'Device limit reached. This account can be active on only 2 devices.',
      activeDevices: activeSessions,
    };
  }

  return prisma.deviceSession.create({
    data: {
      userId,
      ...metadata,
      lastSeenAt: new Date(),
    },
  });
}

function issueToken(user: { id: string; email: string; role: string }, sessionId: string) {
  return jwt.sign(
    { id: user.id, email: user.email, role: user.role, sid: sessionId },
    JWT_SECRET,
    { expiresIn: '30d' },
  );
}

export const signup = async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, email, password } = req.body;

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      res.status(400).json({ error: 'An account already exists with this email.' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: passwordHash,
        role: 'student',
      }
    });

    const deviceSession = await createOrRefreshDeviceSession(req, user.id);
    if ('error' in deviceSession) {
      res.status(403).json(deviceSession);
      return;
    }
    const token = issueToken(user, deviceSession.id);

    await logLogin(req, user.id);
    await logActivity(user.id, 'USER_SIGNUP', { role: user.role, deviceSessionId: deviceSession.id });

    res.status(201).json({ user: publicUser(user), token, session: deviceSession });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'An unexpected error occurred.' });
  }
};

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;
    
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.password) {
      res.status(401).json({ error: 'Invalid credentials or user signed up with Google.' });
      return;
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      res.status(401).json({ error: 'Incorrect password.' });
      return;
    }

    const deviceSession = await createOrRefreshDeviceSession(req, user.id);
    if ('error' in deviceSession) {
      res.status(403).json(deviceSession);
      return;
    }

    const token = issueToken(user, deviceSession.id);

    await logLogin(req, user.id);

    res.status(200).json({ user: publicUser(user), token, session: deviceSession });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'An unexpected error occurred.' });
  }
};

export const googleLogin = async (req: Request, res: Response): Promise<void> => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      res.status(400).json({ error: 'idToken is required' });
      return;
    }
    if (!googleClient) {
      res.status(503).json({ error: 'Google sign-in is not configured on this server.' });
      return;
    }

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: env.GOOGLE_SERVER_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const email = payload?.email;
    if (!email || !payload?.email_verified) {
      res.status(401).json({ error: 'Invalid or unverified Google account.' });
      return;
    }
    const name = payload.name;
    const photoUrl = payload.picture;

    let user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          name: name || 'Google User',
          photoUrl,
          role: 'student',
        }
      });
    } else if (user.password) {
      // A password-based account exists for this email. Silently signing into
      // it would hand an attacker the account by creating a Google account
      // with the victim's verified email. Require the explicit reset flow.
      res.status(409).json({
        error: 'An account with this email already uses a password. Sign in with your password or use "forgot password" to continue.',
      });
      return;
    }

    const deviceSession = await createOrRefreshDeviceSession(req, user.id);
    if ('error' in deviceSession) {
      res.status(403).json(deviceSession);
      return;
    }

    const token = issueToken(user, deviceSession.id);

    await logLogin(req, user.id);

    res.status(200).json({ user: publicUser(user), token, session: deviceSession });
  } catch (error) {
    console.error('Google login error:', error);
    res.status(500).json({ error: 'An unexpected error occurred.' });
  }
};

export const logout = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.deviceSession.updateMany({
      where: {
        id: req.user!.sessionId,
        userId: req.user!.id,
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
    res.status(204).end();
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Failed to logout.' });
  }
};

export const listSessions = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const sessions = await prisma.deviceSession.findMany({
      where: { userId: req.user!.id, revokedAt: null },
      orderBy: { lastSeenAt: 'desc' },
      select: {
        id: true,
        deviceName: true,
        userAgent: true,
        ipAddress: true,
        lastSeenAt: true,
        createdAt: true,
      },
    });
    res.status(200).json(
      sessions.map((session) => ({
        ...session,
        isCurrent: session.id === req.user!.sessionId,
      })),
    );
  } catch (error) {
    console.error('List sessions error:', error);
    res.status(500).json({ error: 'Failed to list device sessions.' });
  }
};

export const revokeSession = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const sessionId = req.params.id;
    if (typeof sessionId !== 'string') {
      res.status(400).json({ error: 'Invalid device session id.' });
      return;
    }
    const result = await prisma.deviceSession.updateMany({
      where: {
        id: sessionId,
        userId: req.user!.id,
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
    if (result.count === 0) {
      res.status(404).json({ error: 'Device session not found.' });
      return;
    }
    res.status(204).end();
  } catch (error) {
    console.error('Revoke session error:', error);
    res.status(500).json({ error: 'Failed to revoke device session.' });
  }
};

const PASSWORD_RESET_TTL_MS = 30 * 60 * 1000; // 30 minutes

const hashResetToken = (token: string) =>
  crypto.createHash('sha256').update(token).digest('hex');

/**
 * Request a password reset. Creates a short-lived token (stored hashed) and
 * returns it only in non-production mode (no email provider configured yet),
 * so the app can complete the flow end-to-end in dev. Production must deliver
 * the token via email.
 */
export const forgotPassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      // Always succeed (enumeration protection): same response whether or not
      // the account exists.
      res.status(200).json({ success: true, message: 'If an account exists, a reset link has been issued.' });
      return;
    }

    await prisma.passwordResetToken.updateMany({
      where: { userId: user.id, usedAt: null },
      data: { usedAt: new Date() },
    });

    const rawToken = crypto.randomBytes(32).toString('hex');
    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash: hashResetToken(rawToken),
        expiresAt: new Date(Date.now() + PASSWORD_RESET_TTL_MS),
      },
    });

    const devToken = env.DEV_ALLOW_RESET_TOKEN_IN_RESPONSE
      ? rawToken
      : undefined;

    if (devToken) {
      console.log(`[dev] Password reset token for ${email}: ${devToken} (expires in 30 min)`);
    }

    await logActivity(user.id, 'PASSWORD_RESET_REQUESTED', { email });

    res.status(200).json({
      success: true,
      message: 'If an account exists, a reset link has been issued.',
      ...(devToken ? { devToken, devTokenExpiresInMinutes: 30 } : {}),
    });
  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({ error: 'Failed to process password reset request.' });
  }
};

/** Complete the reset with token + new password. Invalidates the token. */
export const resetPassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const { token, newPassword } = req.body;

    const record = await prisma.passwordResetToken.findUnique({
      where: { tokenHash: hashResetToken(String(token || '')) },
      include: { user: { select: { id: true, password: true } } },
    });

    if (!record || record.usedAt || record.expiresAt < new Date()) {
      res.status(400).json({ error: 'This reset link is invalid or has expired. Request a new one.' });
      return;
    }
    if (!record.user.password) {
      res.status(400).json({ error: 'This account uses Google sign-in and has no password to reset.' });
      return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: record.userId },
        data: { password: passwordHash },
      }),
      prisma.passwordResetToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      }),
      // Reset on every device: any existing sessions are revoked.
      prisma.deviceSession.updateMany({
        where: { userId: record.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    await logActivity(record.userId, 'PASSWORD_RESET_COMPLETED', {});

    res.status(200).json({ success: true, message: 'Password updated. Please sign in again.' });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ error: 'Failed to reset password.' });
  }
};
