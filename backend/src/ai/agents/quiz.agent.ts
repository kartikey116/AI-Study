import { generateObject } from 'ai';
import { geminiModel, MODELS } from '../providers/models';
import { UNTRUSTED_DATA_RULE, wrapUntrusted } from '../guards/prompt-safety';
import { z } from 'zod';
import * as crypto from 'crypto';
import { prisma } from '../../utils/db.util';
import { sampleDocumentChunks } from '../services/rag.service';
import { logger } from '../../utils/logger';

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
      // Sample across the whole document so questions cover every section
      const chunks = await sampleDocumentChunks(userId, documentId, 10);
      contextText = chunks.map(c => `[Page ${c.pageNumber}] ${c.text}`).join('\n\n');
    }

    // Only trusted values (validated enums/numbers) go in the system prompt; the
    // student-typed title/subject and document text are passed as tagged data below.
    const systemPrompt = `You are an expert tutor creating a quiz with a mix of question types.
The quiz topic is given in <topic> tags${contextText ? ' and the source material in <source_material> tags' : ''}.
${UNTRUSTED_DATA_RULE}
Only create academic study questions. If the topic is not an academic subject, create questions about study skills instead.
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

MATH FORMATTING:
- Write every mathematical expression, formula, exponent, subscript or symbol as LaTeX inside single dollar signs, in the question text, every option and the explanation. Examples: "$2^{20}$ entries", "$\\frac{a}{1-r}$", "$x_1 + x_2$", "$O(n \\log n)$".
- Always brace multi-character exponents and subscripts: $2^{12}$, not 2^12. Never write bare LaTeX commands outside dollar signs.
- Do not use $$...$$ display math. Plain words and ordinary numbers (e.g. "32-bit", "4 KB") stay as normal text.
- correctAnswer must be character-for-character identical to its option, including the dollar signs.

IMPORTANT:
- If a question asks "Which...", "What...", "How...", "Select..." → it MUST be MCQ, never TRUE_FALSE.
- If a question is a statement about a fact → it should be TRUE_FALSE.
- correctAnswer must exactly match one of the options (same text, same capitalization).
${contextText ? '- Base every question on the source material.' : ''}`;

    const prompt = [
      wrapUntrusted('topic', `Title: ${title}\nSubject: ${subject}`),
      contextText ? wrapUntrusted('source_material', contextText) : '',
      'Generate the quiz now.',
    ].filter(Boolean).join('\n\n');

    let generatedQuestions;
    let usage;
    try {
      const result = await generateObject({
        model: geminiModel(MODELS.main),
        schema: z.object({ questions: z.array(questionSchema) }),
        system: systemPrompt,
        prompt,
      });
      generatedQuestions = result.object;
      usage = result.usage;
    } catch (e: any) {
      logger.error({ err: e }, 'Quiz Generation AI Error');
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
          modelName: MODELS.main,
          promptTokens,
          completionTokens,
          totalTokens,
          cost,
          requestType: 'QUIZ_GENERATION'
        }
      }).catch(err => logger.error({ err: err }, 'Failed to log quiz cost'));
    }

    return {
      quizId: quiz.id,
      questionsGenerated: questionsToCreate.length,
      usage
    };
  }
}
