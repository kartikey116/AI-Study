import { generateObject } from 'ai';
import { google } from '@ai-sdk/google';
import { z } from 'zod';
import * as crypto from 'crypto';
import { prisma } from '../../utils/db.util';
import { retrieveChunks } from '../services/rag.service';

const questionSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('MCQ'),
    text: z.string().describe('A question that asks "which", "what", "how", "why", or asks to identify/select something.'),
    options: z.array(z.string()).length(4).describe('Exactly 4 distinct plausible answer choices.'),
    correctAnswer: z.string().describe('Must exactly match one of the 4 options.'),
    explanation: z.string().describe('Brief explanation of why the answer is correct.'),
  }),
  z.object({
    type: z.literal('TRUE_FALSE'),
    text: z.string().describe('A clear factual statement that is either true or false.'),
    options: z.array(z.string()).describe('Always exactly ["True", "False"]'),
    correctAnswer: z.enum(['True', 'False']).describe('Either "True" or "False".'),
    explanation: z.string().describe('Brief explanation of why the statement is true or false.'),
  }),
]);

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

    const systemPrompt = `You are an expert tutor creating a quiz with a mix of question types.
Topic/Title: ${title}
Subject: ${subject}
Difficulty: ${difficulty}
Total Questions: ${numQuestions}

QUESTION TYPE RULES:
1. MCQ (Multiple Choice) — Use when the question asks "which", "what", "how many", "select", or has multiple possible answers to choose from.
   - Must have EXACTLY 4 distinct options (A, B, C, D).
   - The correctAnswer must EXACTLY match one of the 4 options.
   - Example: "Which SQL command is used to add new data?" → options: ["INSERT INTO", "UPDATE", "ADD ROW", "CREATE ROW"]

2. TRUE_FALSE — Use ONLY for clear factual statements that can be judged true or false.
   - The text must be a STATEMENT, not a question. Phrase it as a claim.
   - options must always be ["True", "False"].
   - correctAnswer must be exactly "True" or "False".
   - Example: "In a relational database, a foreign key references the primary key of another table." → True

DISTRIBUTION: Aim for roughly 70% MCQ and 30% TRUE_FALSE questions.

DISTRACTOR QUALITY (CRITICAL FOR MCQ) - Adjusted for ${difficulty} difficulty:
${difficulty === 'Easy' ? `1. Make wrong options plausible but clearly incorrect. Do not use trick questions.
2. Keep the language straightforward. Avoid advanced situational scenarios.
3. Do not use obvious joke answers, but ensure the correct answer is reasonably distinct from the wrong ones.` : ''}
${difficulty === 'Medium' ? `1. Avoid obvious keyword matching between the question and the correct answer.
2. Base wrong options on common misconceptions or typical student mistakes.
3. Wrong options should be conceptually realistic, requiring actual understanding to eliminate.` : ''}
${difficulty === 'Hard' ? `1. NO KEYWORD MATCHING AT ALL.
2. HIGHLY PLAUSIBLE DISTRACTORS: All wrong options must be conceptually very similar to force careful reading.
3. ADVANCED / SITUATIONAL: Formulate the options as applied scenarios, edge-cases, or advanced situational examples rather than simple definitions.
4. TRICKY MISCONCEPTIONS: Base wrong options on subtle mixed-up concepts.` : ''}

IMPORTANT:
- If a question asks "Which...", "What...", "How...", "Select..." → it MUST be MCQ, never TRUE_FALSE.
- If a question is a statement about a fact → it should be TRUE_FALSE.
- correctAnswer must exactly match one of the options (same text, same capitalization).

${contextText ? `=== SOURCE MATERIAL (base your questions on this) ===\n${contextText}\n=================================================` : `Generate questions about "${title}" (within the context of ${subject}).`}`;

    let generatedQuestions;
    let usage;
    try {
      const result = await generateObject({
        model: google('gemini-3.8-flash'),
        schema: z.object({ questions: z.array(questionSchema) }),
        system: systemPrompt,
        prompt: 'Generate the quiz now.',
      });
      generatedQuestions = result.object;
      usage = result.usage;
    } catch (e: any) {
      console.error('Quiz Generation AI Error:', e);
      if (e.statusCode === 429 || e.message?.includes('overloaded')) {
        throw new Error('The AI service is currently overloaded. Please try again in a moment.');
      }
      if (e.statusCode === 400) {
        throw new Error('The AI service failed to generate the required format. Please try again.');
      }
      throw new Error('An unexpected error occurred while generating the quiz. Please try again.');
    }

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

    if (usage) {
      const promptTokens = usage.promptTokens;
      const completionTokens = usage.completionTokens;
      const totalTokens = usage.totalTokens;
      const cost = (totalTokens / 1000000) * 0.15; // Gemini Flash est.

      await prisma.aiRequestLog.create({
        data: {
          userId,
          modelName: 'gemini-3.8-flash',
          promptTokens,
          completionTokens,
          totalTokens,
          cost,
          requestType: 'QUIZ_GENERATION'
        }
      }).catch(err => console.error('Failed to log quiz cost:', err));
    }

    return {
      quizId: quiz.id,
      questionsGenerated: questionsToCreate.length,
      usage
    };
  }
}
