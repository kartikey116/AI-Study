import { Router, Request, Response } from 'express';
import { prisma } from '../utils/db.util';
import { authenticate } from '../middleware/auth.middleware';
import { z } from 'zod';

const router = Router();

// Require authentication for all user routes
router.use(authenticate);

const updateProfileSchema = z.object({
  firstName: z.string().optional(),
  lastName: z.string().optional(),
});

// GET /users/me
router.get('/me', async (req: Request, res: Response): Promise<any> => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      include: { profile: true },
    });

    if (!user) return res.status(404).json({ error: 'User not found' });

    // Exclude passwordHash from response
    const { passwordHash, ...userWithoutPassword } = user;
    return res.json(userWithoutPassword);
  } catch (error) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// PATCH /users/me
router.patch('/me', async (req: Request, res: Response): Promise<any> => {
  try {
    const data = updateProfileSchema.parse(req.body);
    
    const profile = await prisma.profile.update({
      where: { userId: req.userId },
      data,
    });

    return res.json(profile);
  } catch (error: any) {
    if (error instanceof z.ZodError) return res.status(400).json({ error: error.errors });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

export default router;
