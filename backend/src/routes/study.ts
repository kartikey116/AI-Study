import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { prisma } from '../utils/db.util';
import { PlannerAgent } from '../ai/agents/planner.agent';

const router = Router();
const plannerAgent = new PlannerAgent();

router.use(authenticate);

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
router.post('/plan', async (req: Request, res: Response): Promise<any> => {
  const userId = req.userId!;
  if (activePlanGenerations.has(userId)) {
    return res.status(429).json({ error: 'Study plan generation is already in progress. Please wait a moment.' });
  }

  activePlanGenerations.add(userId);
  try {
    const { targetDate, subjects, hoursPerDay } = req.body;
    
    // Clean previous plans so user has one active, up-to-date schedule
    await prisma.studyPlan.deleteMany({
      where: { userId }
    });

    const result = await plannerAgent.generateStudyPlan(
      userId,
      new Date(targetDate),
      subjects || ['General Studies'],
      hoursPerDay || 2
    );

    const fullPlan = await prisma.studyPlan.findUnique({
      where: { id: result.planId },
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
    const task = await prisma.studyTask.findUnique({
      where: { id: req.params.id },
      include: { plan: true }
    });

    if (!task || task.plan.userId !== req.userId) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const updatedTask = await prisma.studyTask.update({
      where: { id: req.params.id },
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
router.post('/session/sync', async (req: Request, res: Response): Promise<any> => {
  try {
    const { durationMinutes, type } = req.body;
    const session = await plannerAgent.syncSession(req.userId!, durationMinutes, type || 'FOCUS_TIMER');
    res.json(session);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to sync session' });
  }
});

export default router;
