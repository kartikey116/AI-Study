import { QuizAgent } from '../src/ai/agents/quiz.agent';
import { prisma } from '../src/utils/db.util';
import dotenv from 'dotenv';
dotenv.config();

async function main() {
  const userId = '5e21775e-a4c2-42b2-bd26-06ccd76e69b8';
  const docId = 'b35bc6b9-4114-4c04-bf39-094057e6a2cb';

  console.log('Generating test quiz from document...');
  const agent = new QuizAgent();
  const result = await agent.generateQuiz(
    userId,
    'OCR Lab Report Quiz',
    'OCR & Healthcare Systems',
    'Medium',
    docId,
    3
  );

  console.log('Quiz Generated Successfully!', result);
  
  const quiz = await prisma.quiz.findUnique({
    where: { id: result.quizId },
    include: { questions: true }
  });

  console.log(`Quiz Title: ${quiz?.title}, Questions count: ${quiz?.questions.length}`);
  for (const q of quiz?.questions || []) {
    console.log(`- [${q.type}] ${q.text}`);
    console.log(`  Ans: ${q.correctAnswer}`);
  }
}

main()
  .catch(err => {
    console.error('Quiz Gen Error:', err);
  })
  .finally(() => {
    process.exit(0);
  });
