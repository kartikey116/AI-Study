import { generateObject } from 'ai';
import { google } from '@ai-sdk/google';
import { z } from 'zod';
import * as crypto from 'crypto';
import { prisma } from '../../utils/db.util';
import { retrieveChunks } from '../services/rag.service';

const questionSchema = z.object({
  type: z.enum(['MCQ', 'TRUE_FALSE', 'SHORT_ANSWER', 'SCENARIO']),
  text: z.string().describe('The actual question text'),
  options: z.array(z.string()).optional().describe('Options for MCQ. Must have exactly 4 items for MCQ.'),
  correctAnswer: z.string().describe('The correct answer. Must exactly match one of the options if MCQ, or True/False for TRUE_FALSE'),
  explanation: z.string().describe('Why this answer is correct'),
});

export class QuizAgent {
  /**
   * Generates a quiz based on a specific document, or general topics if documentId is null.
   */
  async generateQuiz(
    userId: string,
    title: string,
    subject: string,
    difficulty: 'Easy' | 'Medium' | 'Hard',
    documentId?: string,
    numQuestions = 5
  ) {
    // 1. Idempotency Check: Don't burn tokens if a quiz with these exact params already exists
    const existingQuiz = await prisma.quiz.findFirst({
      where: { userId, title, subject, difficulty },
      include: { _count: { select: { questions: true } } }
    });

    if (existingQuiz && existingQuiz._count.questions >= numQuestions) {
      return {
        quizId: existingQuiz.id,
        questionsGenerated: existingQuiz._count.questions,
        cached: true,
        usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 }
      };
    }

    let contextText = '';
    
    if (documentId) {
      // Pull random chunks from the document to seed the quiz generator
      const chunks = await retrieveChunks(userId, 'Give me summary and core concepts', 10, documentId);
      contextText = chunks.map(c => c.text).join('\n\n');
    }

    const systemPrompt = `You are an expert tutor creating a quiz.
Subject: ${subject}
Difficulty: ${difficulty}
Total Questions: ${numQuestions}

Use the provided source material (if any) to generate accurate questions. 
Ensure the questions test understanding, not just rote memorization. 
For MCQ, provide exactly 4 options. 
For TRUE_FALSE, options should be null and correctAnswer should be "True" or "False".
For SHORT_ANSWER, options should be null and correctAnswer should be a brief phrase.
For SCENARIO, present a short paragraph scenario followed by a question.

${contextText ? `=== SOURCE MATERIAL ===\n${contextText}\n========================` : ''}`;

    const { object: generatedQuestions, usage } = await generateObject({
      model: google('gemini-3.8-flash'),
      schema: z.object({ questions: z.array(questionSchema) }),
      system: systemPrompt,
      prompt: 'Generate the quiz now.',
    });

    // 1. Create the Quiz record
    const quiz = await prisma.quiz.create({
      data: {
        userId,
        title,
        subject,
        difficulty,
      },
    });

    // 2. Filter duplicates using contentHash
    const questionsToCreate = [];
    for (const q of generatedQuestions.questions) {
      // Create a deterministic hash of the question text and correct answer
      const hashInput = `${q.type}|${q.text}|${q.correctAnswer}`;
      const contentHash = crypto.createHash('sha256').update(hashInput).digest('hex');

      questionsToCreate.push({
        quizId: quiz.id,
        type: q.type,
        text: q.text,
        options: q.options || [],
        correctAnswer: q.correctAnswer,
        explanation: q.explanation,
        contentHash,
      });
    }

    // 3. Insert questions
    await prisma.question.createMany({
      data: questionsToCreate,
      skipDuplicates: true, 
    });

    return {
      quizId: quiz.id,
      questionsGenerated: questionsToCreate.length,
      usage
    };
  }
}
