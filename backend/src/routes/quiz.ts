import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { prisma } from '../utils/db.util';
import { QuizAgent } from '../ai/agents/quiz.agent';

const router = Router();
const quizAgent = new QuizAgent();

router.use(authenticate);

// Generate a new Quiz
router.post('/generate', async (req: Request, res: Response): Promise<any> => {
  try {
    const { title, subject, difficulty, documentId, numQuestions } = req.body;
    const result = await quizAgent.generateQuiz(
      req.userId!,
      title,
      subject || 'General',
      difficulty || 'Medium',
      documentId,
      numQuestions || 5
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
router.post('/:id/submit', async (req: Request, res: Response): Promise<any> => {
  try {
    const { answers, timeTaken } = req.body; // answers: { questionId: string, userResponse: string, isCorrect: boolean, timeTaken: number }[]
    
    // Calculate total score
    const correctCount = answers.filter((a: any) => a.isCorrect).length;
    const score = (correctCount / answers.length) * 100;

    const attempt = await prisma.quizAttempt.create({
      data: {
        quizId: req.params.id,
        userId: req.userId!,
        score,
        timeTaken,
        answers: {
          create: answers.map((a: any) => ({
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
