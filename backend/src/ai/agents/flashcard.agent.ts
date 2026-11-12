import { generateObject } from 'ai';
import { geminiModel, MODELS } from '../providers/models';
import { UNTRUSTED_DATA_RULE, wrapUntrusted } from '../guards/prompt-safety';
import { z } from 'zod';
import { prisma } from '../../utils/db.util';
import { sampleDocumentChunks } from '../services/rag.service';
import { logger } from '../../utils/logger';

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
      // Sample across the whole document so cards cover every section
      const chunks = await sampleDocumentChunks(userId, documentId, 15);
      contextText = chunks.map(c => `[Page ${c.pageNumber}] ${c.text}`).join('\n\n');
    }

    const systemPrompt = `You are an expert tutor creating flashcards for spaced repetition.
Total Cards: ${numCards}

Create concise, single-concept flashcards.
Front: A clear question or term.
Back: A concise, accurate answer or definition.

The deck topic is given in <topic> tags${contextText ? '; base every card on the <source_material>' : ''}.
${UNTRUSTED_DATA_RULE}
Only create academic study cards.`;

    const prompt = [
      wrapUntrusted('topic', title),
      contextText ? wrapUntrusted('source_material', contextText) : '',
      'Generate the flashcards now.',
    ].filter(Boolean).join('\n\n');

    let generatedCards;
    try {
      const result = await generateObject({
        model: geminiModel(MODELS.main),
        schema: z.object({ cards: z.array(flashcardSchema) }),
        system: systemPrompt,
        prompt,
      });
      generatedCards = result.object;
    } catch (e: any) {
      logger.error({ err: e }, 'Flashcard Generation AI Error');
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
  /** Returns null when the card doesn't exist or belongs to another user's deck. */
  async reviewCard(userId: string, cardId: string, quality: number) {
    const card = await prisma.flashcard.findFirst({ where: { id: cardId, deck: { userId } } });
    if (!card) return null;

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
      where: { id: card.id },
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
