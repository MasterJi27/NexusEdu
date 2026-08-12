import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../lib/env';
import prisma from '../lib/prisma';

const JWT_SECRET = env.JWT_SECRET;

export interface AuthRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
    sessionId: string;
  };
}

type TokenPayload = {
  id: string;
  email: string;
  role: string;
  sid?: string;
};

export const authenticate = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized: No token provided.' });
    return;
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as TokenPayload;
    if (!decoded.sid) {
      res.status(401).json({ error: 'Session expired. Please login again.' });
      return;
    }

    const session = await prisma.deviceSession.findFirst({
      where: {
        id: decoded.sid,
        userId: decoded.id,
        revokedAt: null,
      },
      select: { id: true },
    });

    if (!session) {
      res.status(401).json({ error: 'This device session is no longer active.' });
      return;
    }

    prisma.deviceSession
      .update({
        where: { id: session.id },
        data: {
          lastSeenAt: new Date(),
          ipAddress: req.ip || req.socket.remoteAddress || undefined,
        },
      })
      .catch((error) => console.error('Failed to update session heartbeat:', error));

    req.user = {
      id: decoded.id,
      email: decoded.email,
      role: decoded.role,
      sessionId: session.id,
    };
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized: Invalid token.' });
  }
};
