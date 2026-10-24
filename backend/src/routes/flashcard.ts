import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { generationLimiter } from '../middleware/rate-limit.middleware';
import { prisma } from '../utils/db.util';
import { uuid, promptLabel, validateBody } from '../utils/validation.util';
import { FlashcardAgent } from '../ai/agents/flashcard.agent';
import { DocumentStatus } from '@prisma/client';

const router = Router();
const flashcardAgent = new FlashcardAgent();

router.use(authenticate);

const generateDeckSchema = z.object({
  title: promptLabel,
  documentId: uuid.nullish(),
  numCards: z.number().int().min(1).max(30).default(10),
});

const reviewSchema = z.object({
  quality: z.number().int().min(0).max(5),
});

// Generate a Flashcard Deck
router.post('/generate', generationLimiter, validateBody(generateDeckSchema), async (req: Request, res: Response): Promise<any> => {
  try {
    const { title, documentId, numCards } = req.body as z.infer<typeof generateDeckSchema>;

    // ISOLATION: only the user's own, processed documents can seed a deck
    if (documentId) {
      const owned = await prisma.document.findFirst({
        where: { id: documentId, userId: req.userId!, status: DocumentStatus.READY },
        select: { id: true },
      });
      if (!owned) return res.status(404).json({ error: 'Document not found' });
    }

    const result = await flashcardAgent.generateDeck(
      req.userId!,
      title,
      documentId ?? undefined,
      numCards
    );
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Get all decks
router.get('/decks', async (req: Request, res: Response) => {
  try {
    const decks = await prisma.deck.findMany({
      where: { userId: req.userId! },
      include: {
        _count: { select: { cards: true } },
        cards: {
          where: { nextReviewAt: { lte: new Date() } } // Due cards
        }
      }
    });
    
    // Attach due count
    const result = decks.map(d => ({
      id: d.id,
      title: d.title,
      totalCards: d._count.cards,
      dueCards: d.cards.length
    }));

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get due cards for a deck
router.get('/decks/:id/review', async (req: Request, res: Response): Promise<any> => {
  try {
    // ISOLATION: 404 for decks the user doesn't own (same response as "doesn't exist")
    const deck = await prisma.deck.findFirst({
      where: { id: req.params.id, userId: req.userId! },
      select: { id: true },
    });
    if (!deck) return res.status(404).json({ error: 'Deck not found' });

    const cards = await prisma.flashcard.findMany({
      where: {
        deckId: deck.id,
        deck: { userId: req.userId! },
        nextReviewAt: { lte: new Date() }
      }
    });
    res.json(cards);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Review a card (Submit rating)
router.post('/review/:cardId', validateBody(reviewSchema), async (req: Request, res: Response): Promise<any> => {
  try {
    const { quality } = req.body as z.infer<typeof reviewSchema>;
    const updatedCard = await flashcardAgent.reviewCard(req.userId!, req.params.cardId, quality);
    if (!updatedCard) return res.status(404).json({ error: 'Flashcard not found' });
    res.json(updatedCard);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to review card' });
  }
});

export default router;
