import { Router, Request, Response } from 'express';
import { PrismaClient, Role } from '@prisma/client';
import { authenticate } from '../middleware/auth.middleware';
import { prisma } from '../utils/db.util';
import { StudyOrchestrator } from '../ai/orchestrator';
import { CoreMessage } from 'ai';

const router = Router();
const orchestrator = new StudyOrchestrator();

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
router.post('/', async (req: Request, res: Response): Promise<any> => {
  try {
    const userId = req.userId!;
    const { message, conversationId, documentId } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
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
      const conversation = await prisma.conversation.findUnique({
        where: { id: currentConversationId },
        select: { summary: true }
      });
      summary = conversation?.summary || null;

      recentMessages = await prisma.message.findMany({
        where: { conversationId: currentConversationId },
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

    // 3. Prepare context for AI
    const coreMessages: CoreMessage[] = recentMessages.map((msg) => ({
      role: msg.role === Role.USER ? 'user' : (msg.role === Role.ASSISTANT ? 'assistant' : 'system'),
      content: msg.content,
    }));
    
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

    // 5. Delegate to Orchestrator
    const { stream, intentCostData, citations } = await orchestrator.handleChat(userId, currentConversationId, coreMessages, summary, documentId);

    if (citations && citations.length > 0) {
      res.write(`data: ${JSON.stringify({ type: 'citations', citations })}\n\n`);
    }

    let fullResponse = '';
    let completionTokens = 0;

    // Read the stream
    const reader = stream.textStream.getReader();
    
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      
      fullResponse += value;
      completionTokens += Math.ceil(value.length / 4); // rough estimate
      
      // SSE format requires "data: <payload>\n\n"
      res.write(`data: ${JSON.stringify({ type: 'chunk', text: value })}\n\n`);
    }

    // Done streaming
    res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
    res.end();

    // 6. Post-Processing (Async)
    // Save Assistant Message
    await prisma.message.create({
      data: {
        conversationId: currentConversationId,
        role: Role.ASSISTANT,
        content: fullResponse,
      },
    });

    // Log Generate Cost
    // We don't have exact prompt tokens from stream easily without using full stream object,
    // so we approximate or use usage stream (if supported). For now, rough estimate:
    const promptTokens = Math.ceil(coreMessages.map(m => m.content.toString()).join(' ').length / 4);
    await orchestrator.logCost(userId, {
      modelName: 'gemini-3.8-flash',
      promptTokens,
      completionTokens,
      requestType: 'TUTOR_RESPONSE',
    }).catch(console.error);

    // Trigger summarization if needed (e.g., > 10 messages)
    const totalMessages = await prisma.message.count({ where: { conversationId: currentConversationId } });
    if (totalMessages > 10 && totalMessages % 5 === 0) {
      // Async summarize
      orchestrator.summarizeConversation(coreMessages).then(async ({ summary, costData }) => {
        await prisma.conversation.update({
          where: { id: currentConversationId },
          data: { summary }
        });
        await orchestrator.logCost(userId, costData);
      }).catch(console.error);
    }

  } catch (error) {
    console.error('Chat error:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal server error' });
    } else {
      res.write(`data: ${JSON.stringify({ type: 'error', message: 'Internal server error' })}\n\n`);
      res.end();
    }
  }
});

export default router;
