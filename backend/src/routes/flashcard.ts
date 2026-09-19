import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { prisma } from '../utils/db.util';
import { FlashcardAgent } from '../ai/agents/flashcard.agent';

const router = Router();
const flashcardAgent = new FlashcardAgent();

router.use(authenticate);

// Generate a Flashcard Deck
router.post('/generate', async (req: Request, res: Response): Promise<any> => {
  try {
    const { title, documentId, numCards } = req.body;
    const result = await flashcardAgent.generateDeck(
      req.userId!,
      title,
      documentId,
      numCards || 10
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
    const cards = await prisma.flashcard.findMany({
      where: { 
        deckId: req.params.id,
        nextReviewAt: { lte: new Date() }
      }
    });
    res.json(cards);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Review a card (Submit rating)
router.post('/review/:cardId', async (req: Request, res: Response): Promise<any> => {
  try {
    const { quality } = req.body; // 0-5
    const updatedCard = await flashcardAgent.reviewCard(req.params.cardId, quality);
    res.json(updatedCard);
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to review card' });
  }
});

export default router;
