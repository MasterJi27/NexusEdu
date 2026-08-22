import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import prisma from '../lib/prisma';
import { logLogin, logActivity } from '../lib/logger';
import { env } from '../lib/env';
import { sendEmail } from '../services/digestMailer';
import { AuthRequest } from '../middlewares/auth';

const JWT_SECRET = env.JWT_SECRET;
const googleClient = env.GOOGLE_SERVER_CLIENT_ID ? new OAuth2Client(env.GOOGLE_SERVER_CLIENT_ID) : null;
const MAX_ACTIVE_DEVICE_SESSIONS = Number(process.env.MAX_ACTIVE_DEVICE_SESSIONS || 2);
// Device binding: one device can hold at most this many distinct accounts
// (siblings sharing a phone, etc.). Prevents a single stolen device from
// minting unlimited sessions across accounts.
const MAX_ACCOUNTS_PER_DEVICE = Number(process.env.MAX_ACCOUNTS_PER_DEVICE || 3);

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

  // Wrap count+create in serializable transaction to prevent race where two concurrent
  // requests both pass the count check and then both create, exceeding limits.
  // Fallback: catch P2002 (unique violation on @@unique([userId, deviceId])) and return existing.
  try {
    return await prisma.$transaction(
      async (tx) => {
        const accountsOnDevice = await tx.deviceSession.count({
          where: { deviceId: metadata.deviceId, revokedAt: null },
        });
        if (accountsOnDevice >= MAX_ACCOUNTS_PER_DEVICE) {
          const err: any = new Error('DEVICE_LIMIT_ACCOUNTS');
          err._deviceLimit = {
            error: 'This device is already linked to 3 accounts. Sign out of another account on this device first.',
            activeAccounts: accountsOnDevice,
          };
          throw err;
        }

        const activeSessions = await tx.deviceSession.findMany({
          where: { userId, revokedAt: null },
          orderBy: { lastSeenAt: 'desc' },
          select: { id: true, deviceName: true, lastSeenAt: true, createdAt: true },
        });

        if (activeSessions.length >= MAX_ACTIVE_DEVICE_SESSIONS) {
          const err: any = new Error('DEVICE_LIMIT_SESSIONS');
          err._deviceLimit = {
            error: 'Device limit reached. This account can be active on only 2 devices.',
            activeDevices: activeSessions,
          };
          throw err;
        }

        return tx.deviceSession.create({
          data: {
            userId,
            ...metadata,
            lastSeenAt: new Date(),
          },
        });
      },
      { isolationLevel: 'Serializable' } as any,
    );
  } catch (error: any) {
    if (error?._deviceLimit) return error._deviceLimit;
    // Handle race where concurrent creates violated @@unique([userId, deviceId])
    if (error?.code === 'P2002') {
      const retryExisting = await prisma.deviceSession.findUnique({
        where: { userId_deviceId: { userId, deviceId: metadata.deviceId } },
      });
      if (retryExisting) {
        return prisma.deviceSession.update({
          where: { id: retryExisting.id },
          data: { ...metadata, revokedAt: null, lastSeenAt: new Date() },
        });
      }
    }
    // Also check for PrismaClientKnownRequestError with code P2002
    if (error?.name === 'PrismaClientKnownRequestError' && error?.code === 'P2002') {
      const retryExisting = await prisma.deviceSession.findUnique({
        where: { userId_deviceId: { userId, deviceId: metadata.deviceId } },
      });
      if (retryExisting) {
        return prisma.deviceSession.update({
          where: { id: retryExisting.id },
          data: { ...metadata, revokedAt: null, lastSeenAt: new Date() },
        });
      }
    }
    throw error;
  }
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

    // Institute-manager accounts are usually created by a teacher or
    // principal (who hands over the credentials), but a standalone IM
    // signup is allowed too — the login with those credentials is the same.
    const requestedRole = String(req.body.role || '');

    // HOD is a role a principal assigns to an existing account — there is
    // no self-service HOD signup.
    if (requestedRole === 'hod') {
      res.status(403).json({
        error: 'HOD accounts are assigned by the Principal from the management screen.',
      });
      return;
    }

    // Principal bootstrap: the very first admin can self-signup (the school
    // provisions its own principal). Once an admin exists, signup is closed —
    // further admins are provisioned by the existing one, not created from
    // the public sign-in flow.
    if (requestedRole === 'admin') {
      const adminCount = await prisma.user.count({ where: { role: 'admin' } });
      if (adminCount > 0) {
        res.status(403).json({
          error: 'A Principal already exists. Ask them to create any additional management accounts.',
        });
        return;
      }
    }

    const role = ['teacher', 'parent', 'im', 'admin'].includes(requestedRole)
      ? requestedRole
      : 'student';

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
        role,
      }
    });

    const deviceSession = await createOrRefreshDeviceSession(req, user.id);
    if ('error' in deviceSession) {
      res.status(403).json(deviceSession);
      return;
    }
    const token = issueToken(user, deviceSession.id);

    // NOTE: deliberately no logLogin() here — a fresh account must keep
    // lastLoginAt null so the one-time signup role claim (old app versions)
    // stays allowed. A signup isn't a login.
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

// Device-limit recovery BEFORE login: the user is locked out (limit reached),
// so they have no token to call DELETE /api/auth/sessions/:id. This endpoint
// lets them drop one stale device by proving ownership of the account email
// plus the session id (both already shown to them by the login error). It is
// rate-limited and revokes nothing the caller can't already see.
export const revokeDeviceSessionPreLogin = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, sessionId } = req.body as { email?: string; sessionId?: string };
    const user = await prisma.user.findUnique({
      where: { email: (email ?? '').trim().toLowerCase() },
      select: { id: true },
    });
    if (!user) {
      res.status(404).json({ error: 'No account found for that email.' });
      return;
    }
    const result = await prisma.deviceSession.updateMany({
      where: {
        id: sessionId,
        userId: user.id,
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
    if (result.count === 0) {
      res.status(404).json({ error: 'Device session not found. It may already be removed.' });
      return;
    }
    res.status(204).end();
  } catch (error) {
    console.error('Pre-login revoke error:', error);
    res.status(500).json({ error: 'Failed to remove device.' });
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

    // Six-digit numeric code — short enough to type from the email.
    const rawToken = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
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

    // Deliver the code by email (Composio Gmail → SMTP). In production this
    // is the only delivery path; without a mail backend the flow logs the
    // failure and still returns the generic success response so account
    // existence is never leaked.
    let emailSent = false;
    if (!devToken) {
      emailSent = await sendEmail(
        email,
        'NexusEdu password reset code',
        `Hi ${user.name || 'there'},\n\n` +
          `We got a request to reset your NexusEdu password. Your one-time ` +
          `6-digit reset code (valid for 30 minutes):\n\n  ${rawToken}\n\n` +
          `Open the NexusEdu app → Sign in → Forgot password → enter this code ` +
          `to set a new password.\n\n` +
          `If you didn't request this, you can safely ignore this email.`,
      );
      if (!emailSent) {
        console.error(`[mail] Password reset email for ${email} could not be sent (no mail backend).`);
      }
    }

    await logActivity(user.id, 'PASSWORD_RESET_REQUESTED', { email, emailSent });

    res.status(200).json({
      success: true,
      message: 'If an account exists, a reset link has been issued.',
      ...(devToken ? { devToken, devTokenExpiresInMinutes: 30 } : { emailSent }),
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
