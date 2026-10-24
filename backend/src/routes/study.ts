import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { generationLimiter } from '../middleware/rate-limit.middleware';
import { prisma } from '../utils/db.util';
import { validateBody } from '../utils/validation.util';
import { PlannerAgent } from '../ai/agents/planner.agent';

const router = Router();
const plannerAgent = new PlannerAgent();

router.use(authenticate);

const generatePlanSchema = z.object({
  targetDate: z.string().datetime({ offset: true }).transform(s => new Date(s))
    .refine(d => d.getTime() < Date.now() + 2 * 365 * 24 * 60 * 60 * 1000, 'targetDate must be within 2 years'),
  subjects: z.array(z.string().trim().min(1).max(60)).min(1).max(10).default(['General Studies']),
  hoursPerDay: z.number().min(0.5).max(16).default(2),
});

const syncSessionSchema = z.object({
  durationMinutes: z.number().int().min(1).max(600),
  type: z.enum(['FOCUS_TIMER']).default('FOCUS_TIMER'),
});

// Get Latest Active Study Plan
router.get('/plan', async (req: Request, res: Response): Promise<any> => {
  try {
    const plan = await prisma.studyPlan.findFirst({
      where: { userId: req.userId! },
      orderBy: { createdAt: 'desc' },
      include: {
        tasks: {
          orderBy: { date: 'asc' }
        }
      }
    });
    res.json(plan);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch study plan' });
  }
});

const activePlanGenerations = new Set<string>();

// Generate Study Plan
router.post('/plan', generationLimiter, validateBody(generatePlanSchema), async (req: Request, res: Response): Promise<any> => {
  const userId = req.userId!;
  if (activePlanGenerations.has(userId)) {
    return res.status(429).json({ error: 'Study plan generation is already in progress. Please wait a moment.' });
  }

  activePlanGenerations.add(userId);
  try {
    const { targetDate, subjects, hoursPerDay } = req.body as z.infer<typeof generatePlanSchema>;

    // Clean previous plans so user has one active, up-to-date schedule
    await prisma.studyPlan.deleteMany({
      where: { userId }
    });

    const result = await plannerAgent.generateStudyPlan(
      userId,
      targetDate,
      subjects,
      hoursPerDay
    );

    const fullPlan = await prisma.studyPlan.findFirst({
      where: { id: result.planId, userId },
      include: {
        tasks: {
          orderBy: { date: 'asc' }
        }
      }
    });

    res.json(fullPlan);
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  } finally {
    activePlanGenerations.delete(userId);
  }
});

// Toggle Task Completion
router.patch('/task/:id/toggle', async (req: Request, res: Response): Promise<any> => {
  try {
    const task = await prisma.studyTask.findFirst({
      where: { id: req.params.id, plan: { userId: req.userId! } },
    });

    if (!task) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const updatedTask = await prisma.studyTask.update({
      where: { id: task.id },
      data: { isCompleted: !task.isCompleted }
    });

    res.json(updatedTask);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// Delete a Study Plan
router.delete('/plan/:id', async (req: Request, res: Response): Promise<any> => {
  try {
    const plan = await prisma.studyPlan.findFirst({
      where: { id: req.params.id, userId: req.userId! }
    });

    if (!plan) {
      return res.status(404).json({ error: 'Plan not found' });
    }

    await prisma.studyPlan.delete({
      where: { id: req.params.id }
    });

    res.json({ message: 'Plan deleted successfully' });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to delete plan' });
  }
});

// Dashboard Summary
router.get('/dashboard', async (req: Request, res: Response): Promise<any> => {
  try {
    const summary = await plannerAgent.getDashboardSummary(req.userId!);
    res.json(summary);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch dashboard summary' });
  }
});

// Sync Study Session
router.post('/session/sync', validateBody(syncSessionSchema), async (req: Request, res: Response): Promise<any> => {
  try {
    const { durationMinutes, type } = req.body as z.infer<typeof syncSessionSchema>;
    const session = await plannerAgent.syncSession(req.userId!, durationMinutes, type);
    res.json(session);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to sync session' });
  }
});

export default router;
