import { PrismaClient } from '@prisma/client';
import { Request } from 'express';

const prisma = new PrismaClient();

export const logActivity = async (userId: string, action: string, metadata?: any) => {
  try {
    await prisma.activityLog.create({
      data: {
        userId,
        action,
        metadata: metadata || {}
      }
    });
  } catch (error) {
    console.error('Failed to log activity:', error);
  }
};

export const logLogin = async (req: Request, userId: string) => {
  try {
    const ipAddress = req.ip || req.connection.remoteAddress || 'unknown';
    const deviceInfo = req.headers['user-agent'] || 'unknown';
    
    await prisma.loginLog.create({
      data: {
        userId,
        ipAddress,
        deviceInfo
      }
    });

    // Also update lastLoginAt on User
    await prisma.user.update({
      where: { id: userId },
      data: { lastLoginAt: new Date() }
    });
  } catch (error) {
    console.error('Failed to log login:', error);
  }
};
