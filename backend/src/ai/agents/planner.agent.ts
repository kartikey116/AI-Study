import { generateObject, generateText } from 'ai';
import { geminiModel, MODELS } from '../providers/models';
import { UNTRUSTED_DATA_RULE, wrapUntrusted } from '../guards/prompt-safety';
import { cacheGet, cacheSet } from '../../utils/cache.util';
import { logger } from '../../utils/logger';
import { createHash } from 'crypto';
import { z } from 'zod';
import { prisma } from '../../utils/db.util';

const studyTaskSchema = z.object({
  title: z.string(),
  durationMinutes: z.number(),
  type: z.enum(['REVISION', 'QUIZ', 'READING']),
});

export class PlannerAgent {

  /**
   * Generates a study plan
   */
  async generateStudyPlan(userId: string, targetDate: Date, subjects: string[], hoursPerDay: number) {
    // 1. Idempotency Check: Avoid generating a new plan if one exists for this target date
    const existingPlan = await prisma.studyPlan.findFirst({
      where: { userId, targetDate },
      include: { tasks: true }
    });

    if (existingPlan && existingPlan.tasks.length > 0) {
      return { planId: existingPlan.id, tasks: existingPlan.tasks, cached: true };
    }

    // Subjects are student-typed, so they're passed as tagged data, not in the system prompt
    const systemPrompt = `You are an expert study planner.
The subjects the student wants to study are given in <topic> tags.
${UNTRUSTED_DATA_RULE}
They have an exam/target date on ${targetDate.toISOString().split('T')[0]}.
They can study ${hoursPerDay} hours per day.

Generate a list of exactly 7 study tasks for the upcoming week.
Mix REVISION, QUIZ, and READING.`;

    let planData;
    try {
      const result = await generateObject({
        model: geminiModel(MODELS.main),
        schema: z.object({ tasks: z.array(studyTaskSchema) }),
        system: systemPrompt,
        prompt: `${wrapUntrusted('topic', subjects.join('\n'))}\n\nGenerate the 7-day plan.`,
      });
      planData = result.object;
    } catch (e: any) {
      logger.error({ err: e }, 'Planner AI Error');
      if (e.statusCode === 429 || e.message?.includes('overloaded')) {
        throw new Error('The AI service is currently overloaded. Please try again in a moment.');
      }
      if (e.statusCode === 400) {
        throw new Error('The AI service failed to generate the required format. Please try again.');
      }
      throw new Error('An unexpected error occurred while generating the study plan. Please try again.');
    }

    const plan = await prisma.studyPlan.create({
      data: {
        userId,
        targetDate,
        subjects,
      }
    });

    const tasksToCreate = planData.tasks.map((t, index) => {
      const taskDate = new Date();
      taskDate.setDate(taskDate.getDate() + index); // assign 1 task per day
      return {
        planId: plan.id,
        title: t.title,
        date: taskDate,
        durationMinutes: t.durationMinutes,
        type: t.type,
      };
    });

    await prisma.studyTask.createMany({ data: tasksToCreate });

    return { planId: plan.id, tasks: tasksToCreate };
  }

  /**
   * Evaluates topic mastery and returns a dashboard summary (cached on client side)
   */
  async getDashboardSummary(userId: string) {
    // Fetch user's recent performance
    const masteries = await prisma.topicMastery.findMany({
      where: { userId },
      orderBy: { masteryLevel: 'asc' },
      take: 3
    });

    let nextAction = "Start learning by uploading a document.";
    let tip = "Upload a PDF study guide to begin your journey!";
    // Check documents count
    const docsCount = await prisma.document.count({ where: { userId } });

    if (masteries.length > 0) {
      const weakest = masteries[0];
      nextAction = `Revise ${weakest.topic}`;

      // Cached per user + topic + mastery level: the dashboard loads often, the tip rarely changes
      const mastery = Math.round(weakest.masteryLevel);
      const cacheKey = `tip:${userId}:${createHash('sha256').update(`${weakest.topic}|${mastery}`).digest('hex').slice(0, 16)}`;
      const cachedTip = await cacheGet<string>(cacheKey);

      if (cachedTip) {
        tip = cachedTip;
      } else {
        try {
          const { text } = await generateText({
            model: geminiModel(MODELS.fast),
            system: `Give a short, motivating 1-sentence study tip for improving the topic in <topic> tags.\n${UNTRUSTED_DATA_RULE}`,
            prompt: `${wrapUntrusted('topic', weakest.topic)}\nCurrent mastery: ${mastery}%`,
          });
          tip = text.trim();
          await cacheSet(cacheKey, tip, 12 * 60 * 60);
        } catch (e) {
          logger.error({ err: e }, 'Tip generation failed');
          tip = "Keep studying to improve your weakest topic!";
        }
      }
    } else if (docsCount > 0) {
      nextAction = "Take a Quiz";
      tip = "Try generating a quiz from your uploaded documents to test your knowledge!";
    }

    // ── 1. Study Time (Focus sessions + Quiz attempts) ─────────
    const [studySessions, quizAttempts] = await Promise.all([
      prisma.studySession.findMany({
        where: { userId },
        select: { durationMinutes: true, createdAt: true },
      }),
      prisma.quizAttempt.findMany({
        where: { userId },
        select: { timeTaken: true, createdAt: true },
      }),
    ]);

    const sessionMinutes = studySessions.reduce((sum, s) => sum + s.durationMinutes, 0);
    const quizMinutes = Math.round(quizAttempts.reduce((sum, q) => sum + q.timeTaken, 0) / 60);
    const totalMinutes = sessionMinutes + quizMinutes;
    const hours = Math.floor(totalMinutes / 60);
    const mins = totalMinutes % 60;
    const studyTime = totalMinutes === 0 ? "0m" : (hours > 0 ? `${hours}h ${mins}m` : `${mins}m`);

    // ── 2. Tasks Completed (Completed study tasks + quizzes completed) ─
    const completedTasksCount = await prisma.studyTask.count({
      where: {
        plan: { userId },
        isCompleted: true,
      },
    });
    const tasksCompleted = (completedTasksCount + quizAttempts.length).toString();

    // ── 3. Streak Days (Consecutive days with study sessions, quizzes, or tasks) ─
    const activeDateStrings = new Set<string>();
    for (const s of studySessions) {
      activeDateStrings.add(s.createdAt.toISOString().slice(0, 10));
    }
    for (const q of quizAttempts) {
      activeDateStrings.add(q.createdAt.toISOString().slice(0, 10));
    }

    let streak = 0;
    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const yesterdayStr = yesterday.toISOString().slice(0, 10);

    let checkDate = activeDateStrings.has(todayStr) ? now : (activeDateStrings.has(yesterdayStr) ? yesterday : null);

    if (checkDate) {
      while (true) {
        const dateStr = checkDate.toISOString().slice(0, 10);
        if (activeDateStrings.has(dateStr)) {
          streak++;
          checkDate = new Date(checkDate.getTime() - 24 * 60 * 60 * 1000);
        } else {
          break;
        }
      }
    }
    const streakDays = `${streak} Days`;

    // ── 4. Learner Level (XP system based on activity) ────────
    const totalXP = (quizAttempts.length * 50) + (sessionMinutes * 4) + (completedTasksCount * 30) + (docsCount * 25);
    const levelNumber = Math.max(1, Math.floor(totalXP / 200) + 1);
    const userLevel = `Level ${levelNumber}`;

    return {
      tip,
      nextAction,
      studyTime,
      tasksCompleted,
      streakDays,
      userLevel,
      masteries: masteries.map(m => ({ topic: m.topic, mastery: m.masteryLevel }))
    };
  }

  /**
   * Sync an offline focus timer session and update mastery slightly based on time spent
   */
  async syncSession(userId: string, durationMinutes: number, type: string) {
    return prisma.studySession.create({
      data: {
        userId,
        durationMinutes,
        type,
      }
    });
  }
}
