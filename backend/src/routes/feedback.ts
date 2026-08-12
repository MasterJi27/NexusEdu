import { Response } from 'express';
import { Router } from 'express';
import { z } from 'zod';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import prisma from '../lib/prisma';

const router = Router();

const feedbackSchema = z.object({
  rating: z.number().int().min(1).max(5),
  category: z.string().max(100).optional(),
  comment: z.string().max(2000).optional(),
});

router.post('/', authenticate, validateBody(feedbackSchema), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { rating, category, comment } = req.body;

    // Save feedback as an activity log entry
    const log = await prisma.activityLog.create({
      data: {
        userId,
        action: 'SUBMITTED_FEEDBACK',
        metadata: {
          rating,
          category: category || 'General',
          comment: comment || '',
        },
      },
    });

    // Award 20 XP to the user
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        xp: { increment: 20 },
      },
      select: {
        id: true,
        xp: true,
      },
    });

    res.status(200).json({
      success: true,
      message: 'Feedback submitted successfully.',
      xpAwarded: 20,
      newXp: updatedUser.xp,
    });
  } catch (error: any) {
    console.error('Feedback submit error:', error);
    res.status(500).json({ error: 'Failed to submit feedback.', details: error.message });
  }
});

export default router;
