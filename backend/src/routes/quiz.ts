import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { generationLimiter } from '../middleware/rate-limit.middleware';
import { prisma } from '../utils/db.util';
import { uuid, promptLabel, validateBody } from '../utils/validation.util';
import { QuizAgent } from '../ai/agents/quiz.agent';
import { DocumentStatus } from '@prisma/client';

const router = Router();
const quizAgent = new QuizAgent();

router.use(authenticate);

const generateQuizSchema = z.object({
  title: promptLabel,
  subject: promptLabel.default('General'),
  difficulty: z.enum(['Easy', 'Medium', 'Hard']).default('Medium'),
  documentId: uuid.nullish(),
  numQuestions: z.number().int().min(1).max(30).default(5),
});

const submitAttemptSchema = z.object({
  answers: z.array(z.object({
    questionId: uuid,
    userResponse: z.string().max(1000),
    timeTaken: z.number().int().min(0).max(86_400).default(0),
  })).min(1).max(100),
  timeTaken: z.number().int().min(0).max(86_400),
});

// Generate a new Quiz
router.post('/generate', generationLimiter, validateBody(generateQuizSchema), async (req: Request, res: Response): Promise<any> => {
  try {
    const { title, subject, difficulty, documentId, numQuestions } = req.body as z.infer<typeof generateQuizSchema>;

    // ISOLATION: only the user's own, processed documents can seed a quiz
    if (documentId) {
      const owned = await prisma.document.findFirst({
        where: { id: documentId, userId: req.userId!, status: DocumentStatus.READY },
        select: { id: true },
      });
      if (!owned) return res.status(404).json({ error: 'Document not found' });
    }

    const result = await quizAgent.generateQuiz(
      req.userId!,
      title,
      subject,
      difficulty,
      documentId ?? undefined,
      numQuestions
    );
    res.json(result);
  } catch (error: any) {
    console.error('Quiz generation error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Get all quizzes
router.get('/', async (req: Request, res: Response) => {
  try {
    const quizzes = await prisma.quiz.findMany({
      where: { userId: req.userId! },
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { questions: true } },
        attempts: {
          where: { userId: req.userId! },
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            id: true,
            score: true,
            timeTaken: true,
            createdAt: true,
          }
        }
      }
    });
    res.json(quizzes);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete a quiz
router.delete('/:id', async (req: Request, res: Response): Promise<any> => {
  try {
    await prisma.quiz.deleteMany({
      where: { id: req.params.id, userId: req.userId! }
    });
    res.json({ message: 'Quiz deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete quiz' });
  }
});

// Get a specific quiz with questions
router.get('/:id', async (req: Request, res: Response): Promise<any> => {
  try {
    const quiz = await prisma.quiz.findFirst({
      where: { id: req.params.id, userId: req.userId! },
      include: { questions: true }
    });
    if (!quiz) return res.status(404).json({ error: 'Quiz not found' });
    res.json(quiz);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Submit a quiz attempt
router.post('/:id/submit', validateBody(submitAttemptSchema), async (req: Request, res: Response): Promise<any> => {
  try {
    const { answers, timeTaken } = req.body as z.infer<typeof submitAttemptSchema>;

    // ISOLATION: the quiz must belong to this user, and every answer must reference
    // one of that quiz's questions.
    const quiz = await prisma.quiz.findFirst({
      where: { id: req.params.id, userId: req.userId! },
      select: { id: true, questions: { select: { id: true, correctAnswer: true } } },
    });
    if (!quiz) return res.status(404).json({ error: 'Quiz not found' });

    const correctAnswers = new Map(quiz.questions.map(q => [q.id, q.correctAnswer]));
    if (answers.some(a => !correctAnswers.has(a.questionId))) {
      return res.status(400).json({ error: 'Answer references a question that is not in this quiz' });
    }

    // Grade on the server — the client's own isCorrect flag is ignored
    const graded = answers.map(a => ({ ...a, isCorrect: a.userResponse === correctAnswers.get(a.questionId) }));
    const correctCount = graded.filter(a => a.isCorrect).length;
    const score = (correctCount / graded.length) * 100;

    const attempt = await prisma.quizAttempt.create({
      data: {
        quizId: quiz.id,
        userId: req.userId!,
        score,
        timeTaken,
        answers: {
          create: graded.map(a => ({
            questionId: a.questionId,
            userResponse: a.userResponse,
            isCorrect: a.isCorrect,
            timeTaken: a.timeTaken
          }))
        }
      }
    });

    res.json(attempt);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to submit attempt' });
  }
});

export default router;
