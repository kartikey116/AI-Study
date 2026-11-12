import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { Role, DocumentStatus } from '@prisma/client';
import { authenticate } from '../middleware/auth.middleware';
import { chatLimiter } from '../middleware/rate-limit.middleware';
import { prisma } from '../utils/db.util';
import { uuid, validateBody } from '../utils/validation.util';
import { StudyOrchestrator } from '../ai/orchestrator';
import { MODELS } from '../ai/providers/models';
import { LeakGuard, LEAK_REPLACEMENT } from '../ai/guards/prompt-safety';
import { logger } from '../utils/logger';
import { CoreMessage } from 'ai';

const EMPTY_ANSWER_FALLBACK = "I couldn't generate an answer to that. Could you rephrase your question about the topic you're studying?";

const router = Router();
const orchestrator = new StudyOrchestrator();

const chatSchema = z.object({
  message: z.string().trim().min(1).max(4000),
  conversationId: uuid.optional(),
  documentId: z.union([z.literal('ALL'), z.literal('GENERAL'), uuid]).optional(),
});

// Apply auth middleware to all chat routes
router.use(authenticate);

// GET /conversations
router.get('/conversations', async (req: Request, res: Response) => {
  try {
    const conversations = await prisma.conversation.findMany({
      where: { userId: req.userId },
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        title: true,
        summary: true,
        createdAt: true,
        updatedAt: true,
        _count: {
          select: { messages: true }
        }
      }
    });
    res.json(conversations);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch conversations' });
  }
});

// GET /conversations/:id
router.get('/conversations/:id', async (req: Request, res: Response): Promise<any> => {
  try {
    const conversation = await prisma.conversation.findFirst({
      where: { 
        id: req.params.id,
        userId: req.userId 
      },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' }
        }
      }
    });

    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    res.json(conversation);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch conversation' });
  }
});

// POST /chat
router.post('/', chatLimiter, validateBody(chatSchema), async (req: Request, res: Response): Promise<any> => {
  try {
    const userId = req.userId!;
    const { message, conversationId, documentId } = req.body as z.infer<typeof chatSchema>;

    // ISOLATION: a conversation or document id from the client is only usable if it
    // belongs to this user. Checked before anything is read, written, or sent to the AI.
    if (conversationId) {
      const owned = await prisma.conversation.findFirst({
        where: { id: conversationId, userId },
        select: { id: true },
      });
      if (!owned) return res.status(404).json({ error: 'Conversation not found' });
    }
    if (documentId && documentId !== 'ALL' && documentId !== 'GENERAL') {
      const owned = await prisma.document.findFirst({
        where: { id: documentId, userId, status: DocumentStatus.READY },
        select: { id: true },
      });
      if (!owned) return res.status(404).json({ error: 'Document not found' });
    }

    let currentConversationId = conversationId;
    let summary: string | null = null;
    let recentMessages: any[] = [];

    // 1. Manage Conversation & Context
    if (!currentConversationId) {
      const conversation = await prisma.conversation.create({
        data: {
          userId: userId,
          title: message.substring(0, 30) + '...',
        },
      });
      currentConversationId = conversation.id;
    } else {
      // Fetch recent messages and summary
      // userId stays in every query as defense in depth, even after the ownership check
      const conversation = await prisma.conversation.findFirst({
        where: { id: currentConversationId, userId },
        select: { summary: true }
      });
      summary = conversation?.summary || null;

      recentMessages = await prisma.message.findMany({
        where: { conversationId: currentConversationId, conversation: { userId } },
        orderBy: { createdAt: 'desc' },
        take: 10, // Only send the last 10 messages for context
      });
      recentMessages = recentMessages.reverse(); // put back in chronological order
    }

    // 2. Save User Message
    await prisma.message.create({
      data: {
        conversationId: currentConversationId,
        role: Role.USER,
        content: message,
      },
    });

    // 3. Prepare context for AI (only user/assistant turns are ever stored or sent)
    const coreMessages: CoreMessage[] = recentMessages
      .filter((msg) => msg.role === Role.USER || msg.role === Role.ASSISTANT)
      .map((msg) => ({ role: msg.role === Role.USER ? 'user' : 'assistant', content: msg.content }));

    // Add the new user message
    coreMessages.push({ role: 'user', content: message });

    // 4. Setup SSE headers and acknowledge stream immediately (prevents client receive timeout)
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    if (typeof (res as any).flushHeaders === 'function') {
      (res as any).flushHeaders();
    }
    // Send immediate initial meta packet so client connection starts within milliseconds
    res.write(`data: ${JSON.stringify({ type: 'meta', conversationId: currentConversationId })}\n\n`);

    // Stop generating (and paying for) tokens if the student closes the app mid-answer
    const abort = new AbortController();
    res.on('close', () => { if (!res.writableEnded) abort.abort(); });

    // 5. Delegate to Orchestrator
    const { textStream, usage, citations, blocked } = await orchestrator.handleChat(userId, coreMessages, summary, documentId, abort.signal);

    if (citations.length > 0) {
      res.write(`data: ${JSON.stringify({ type: 'citations', citations })}\n\n`);
    }

    // The leak guard holds back a short tail so system-prompt text can be caught before it's sent
    const guard = new LeakGuard();
    const send = (text: string) => { if (text) res.write(`data: ${JSON.stringify({ type: 'chunk', text })}\n\n`); };

    const reader = textStream.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        send(guard.push(value));
        if (guard.leaked) {
          abort.abort();
          logger.warn({ userId, conversationId: currentConversationId }, 'Blocked system-prompt leak in tutor output');
          break;
        }
      }
    } catch (err: any) {
      if (!abort.signal.aborted) throw err;
    }

    if (abort.signal.aborted && !guard.leaked) {
      // Client disconnected: nothing more to send. Keep what they saw so history stays consistent.
      logger.info({ userId, conversationId: currentConversationId }, 'Client disconnected; generation aborted');
    } else {
      send(guard.flush());
      if (guard.leaked) send(LEAK_REPLACEMENT);
      // Gemini's safety filter (or an empty completion) yields no text: never leave the student with a blank bubble
      if (!guard.shownText.trim()) send(EMPTY_ANSWER_FALLBACK);
      res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
      res.end();
    }

    // 6. Post-Processing (Async)
    const shown = guard.shownText.trim() || (abort.signal.aborted ? '' : EMPTY_ANSWER_FALLBACK);
    if (shown) {
      await prisma.message.create({
        data: { conversationId: currentConversationId, role: Role.ASSISTANT, content: shown },
      });
    }

    // Real token usage from the API (aborted streams may not report it)
    if (usage) {
      usage.then(u => orchestrator.logCost(userId, {
        modelName: MODELS.main, promptTokens: u.promptTokens, completionTokens: u.completionTokens, requestType: 'TUTOR_RESPONSE',
      })).catch(err => logger.debug({ err: err?.message }, 'No usage reported for tutor response'));
    }

    // Rolling summary every 5 messages once the chat is long
    const totalMessages = await prisma.message.count({ where: { conversationId: currentConversationId, conversation: { userId } } });
    if (!blocked && totalMessages > 10 && totalMessages % 5 === 0) {
      orchestrator.summarizeConversation(summary, coreMessages).then(async ({ summary: newSummary, costData }) => {
        await prisma.conversation.updateMany({
          where: { id: currentConversationId, userId },
          data: { summary: newSummary }
        });
        await orchestrator.logCost(userId, costData);
      }).catch(err => logger.error({ err }, 'Summarization failed'));
    }

  } catch (error: any) {
    logger.error({ err: error, userId: req.userId }, 'Chat error');
    if (res.writableEnded || res.destroyed) return;
    let errorMsg = 'An unexpected error occurred while generating the response.';
    if (error.statusCode === 429 || error.message?.includes('overloaded')) {
      errorMsg = 'The AI service is currently overloaded. Please try again in a moment.';
    } else if (error.statusCode >= 400 && error.statusCode < 500) {
      errorMsg = 'The AI service encountered an error processing your request.';
    }

    if (!res.headersSent) {
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      if (typeof (res as any).flushHeaders === 'function') {
        (res as any).flushHeaders();
      }
    }
    res.write(`data: ${JSON.stringify({ type: 'error', message: errorMsg })}\n\n`);
    res.end();
  }
});

export default router;
