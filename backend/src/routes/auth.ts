import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '../utils/db.util';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt.util';
import { authenticate } from '../middleware/auth.middleware';

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

// POST /auth/register
router.post('/register', async (req: Request, res: Response): Promise<any> => {
  try {
    const data = registerSchema.parse(req.body);
    
    const existingUser = await prisma.user.findUnique({ where: { email: data.email } });
    if (existingUser) {
      return res.status(400).json({ error: 'User with this email already exists' });
    }

    const passwordHash = await bcrypt.hash(data.password, 10);

    const user = await prisma.user.create({
      data: {
        email: data.email,
        passwordHash,
        profile: {
          create: {
            firstName: data.firstName,
            lastName: data.lastName,
          }
        }
      },
    });

    const device = await prisma.device.create({
      data: { userId: user.id, deviceInfo: req.headers['user-agent'] }
    });

    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id, device.id);

    await prisma.refreshToken.create({
      data: { token: refreshToken, userId: user.id, deviceId: device.id, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) }
    });

    return res.status(201).json({ accessToken, refreshToken });
  } catch (error: any) {
    if (error instanceof z.ZodError) return res.status(400).json({ error: error.errors });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// POST /auth/login
router.post('/login', async (req: Request, res: Response): Promise<any> => {
  try {
    const data = loginSchema.parse(req.body);
    
    const user = await prisma.user.findUnique({ where: { email: data.email } });
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    const isValidPassword = await bcrypt.compare(data.password, user.passwordHash);
    if (!isValidPassword) return res.status(401).json({ error: 'Invalid credentials' });

    const device = await prisma.device.create({
      data: { userId: user.id, deviceInfo: req.headers['user-agent'] }
    });

    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id, device.id);

    await prisma.refreshToken.create({
      data: { token: refreshToken, userId: user.id, deviceId: device.id, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) }
    });

    return res.json({ accessToken, refreshToken });
  } catch (error: any) {
    if (error instanceof z.ZodError) return res.status(400).json({ error: error.errors });
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req: Request, res: Response): Promise<any> => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Refresh token required' });

    const decoded = verifyRefreshToken(refreshToken);
    
    // Check if token exists in DB and is not revoked
    const storedToken = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!storedToken || storedToken.revokedAt || storedToken.expiresAt < new Date()) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    // Revoke old token
    await prisma.refreshToken.update({
      where: { id: storedToken.id },
      data: { revokedAt: new Date() }
    });

    const newAccessToken = generateAccessToken(decoded.userId);
    const newRefreshToken = generateRefreshToken(decoded.userId, decoded.deviceId);

    await prisma.refreshToken.create({
      data: { token: newRefreshToken, userId: decoded.userId, deviceId: decoded.deviceId, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) }
    });

    return res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }
});

// POST /auth/logout
router.post('/logout', authenticate, async (req: Request, res: Response): Promise<any> => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await prisma.refreshToken.update({
        where: { token: refreshToken },
        data: { revokedAt: new Date() }
      }).catch(() => {}); // ignore if not found
    }
    return res.json({ message: 'Logged out successfully' });
  } catch (error) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
});

export default router;
