import { generateObject } from 'ai';
import { google } from '@ai-sdk/google';
import { z } from 'zod';
import { prisma } from '../../utils/db.util';
import { retrieveChunks } from '../services/rag.service';

const flashcardSchema = z.object({
  front: z.string().describe('The question or term on the front of the card'),
  back: z.string().describe('The answer or definition on the back of the card'),
});

export class FlashcardAgent {
  
  /**
   * Generates a deck of flashcards based on a document or topic.
   */
  async generateDeck(userId: string, title: string, documentId?: string, numCards = 10) {
    // 1. Idempotency Check
    const existingDeck = await prisma.deck.findFirst({
      where: { userId, title },
      include: { _count: { select: { cards: true } } }
    });

    if (existingDeck && existingDeck._count.cards > 0) {
      return { 
        deckId: existingDeck.id, 
        cardsGenerated: existingDeck._count.cards,
        cached: true 
      };
    }

    let contextText = '';
    
    if (documentId) {
      const chunks = await retrieveChunks(userId, 'Core facts, definitions, and key concepts', 15, documentId);
      contextText = chunks.map(c => c.text).join('\n\n');
    }

    const systemPrompt = `You are an expert tutor creating flashcards for spaced repetition.
Total Cards: ${numCards}

Create concise, single-concept flashcards. 
Front: A clear question or term.
Back: A concise, accurate answer or definition.

${contextText ? `=== SOURCE MATERIAL ===\n${contextText}\n========================` : ''}`;

    let generatedCards;
    try {
      const result = await generateObject({
        model: google('gemini-3.8-flash'),
        schema: z.object({ cards: z.array(flashcardSchema) }),
        system: systemPrompt,
        prompt: 'Generate the flashcards now.',
      });
      generatedCards = result.object;
    } catch (e: any) {
      console.error('Flashcard Generation AI Error:', e);
      if (e.statusCode === 429 || e.message?.includes('overloaded')) {
        throw new Error('The AI service is currently overloaded. Please try again in a moment.');
      }
      if (e.statusCode === 400) {
        throw new Error('The AI service failed to generate the required format. Please try again.');
      }
      throw new Error('An unexpected error occurred while generating flashcards. Please try again.');
    }

    const deck = await prisma.deck.create({
      data: {
        userId,
        title,
      }
    });

    await prisma.flashcard.createMany({
      data: generatedCards.cards.map(c => ({
        deckId: deck.id,
        front: c.front,
        back: c.back,
      }))
    });

    return { deckId: deck.id, cardsGenerated: generatedCards.cards.length };
  }

  /**
   * Applies the SuperMemo-2 (SM-2) algorithm to update a flashcard's schedule.
   * @param quality 0-5 (0 = complete blackout, 3 = hard, 4 = good, 5 = perfect)
   */
  async reviewCard(cardId: string, quality: number) {
    const card = await prisma.flashcard.findUnique({ where: { id: cardId } });
    if (!card) throw new Error('Flashcard not found');

    let { interval, easeFactor, reviewCount } = card;

    if (quality >= 3) {
      if (reviewCount === 0) {
        interval = 1;
      } else if (reviewCount === 1) {
        interval = 6;
      } else {
        interval = Math.round(interval * easeFactor);
      }
      reviewCount += 1;
    } else {
      reviewCount = 0;
      interval = 1;
    }

    easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (easeFactor < 1.3) easeFactor = 1.3;

    const nextReviewAt = new Date();
    nextReviewAt.setDate(nextReviewAt.getDate() + interval);

    const updatedCard = await prisma.flashcard.update({
      where: { id: cardId },
      data: {
        interval,
        easeFactor,
        reviewCount,
        lastReviewedAt: new Date(),
        nextReviewAt,
      }
    });

    return updatedCard;
  }
}
