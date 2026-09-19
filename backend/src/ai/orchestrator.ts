import { CoreMessage, StreamTextResult } from 'ai';
import { AIProvider } from './providers/ai-provider.interface';
import { GeminiProvider } from './providers/gemini.provider';
import { IntentRouter } from './routers/intent.router';
import { TutorAgent } from './agents/tutor.agent';
import { prisma } from '../utils/db.util';
import { StudyIntent } from './routers/intent.router';
import { retrieveChunks, rerank, buildRagContext } from './services/rag.service';

export class StudyOrchestrator {
  private provider: AIProvider;
  private intentRouter: IntentRouter;
  private tutorAgent: TutorAgent;

  constructor() {
    // Currently hardcoded to Gemini, but easy to abstract or route based on config
    this.provider = new GeminiProvider();
    this.intentRouter = new IntentRouter(this.provider);
    this.tutorAgent = new TutorAgent(this.provider);
  }

  async handleChat(
    userId: string, 
    conversationId: string, 
    messages: CoreMessage[],
    summary?: string | null,
    documentId?: string
  ): Promise<{ stream: StreamTextResult<any>, intentCostData: any, citations: any[] }> {
    
    // 1. Detect Intent
    const { intent, costData: intentCostData } = await this.intentRouter.detectIntent(messages);

    // Log the intent cost asynchronously
    this.logCost(userId, intentCostData).catch(console.error);

    let finalMessages = [...messages];
    let finalCitations: any[] = [];

    // 2. RAG Retrieval if needed
    const shouldDoRag = (documentId && documentId !== 'GENERAL') || intent === StudyIntent.RAG_QUERY;
    if (shouldDoRag) {
      const userMessage = messages[messages.length - 1].content as string;
      const targetDocId = (documentId === 'ALL' || documentId === 'GENERAL') ? undefined : documentId;
      const chunks = await retrieveChunks(userId, userMessage, 8, targetDocId);
      const topChunks = rerank(chunks, 4);
      
      const { contextText, citations } = buildRagContext(topChunks);
      finalCitations = citations;

      if (contextText) {
        // Inject context as a system message right before the user's message
        const lastMsg = finalMessages.pop()!;
        finalMessages.push({ 
          role: 'system', 
          content: `=== DOCUMENT CONTEXT / SOURCE MATERIAL ===\n${contextText}\n==========================================` 
        });
        finalMessages.push(lastMsg);
      }
    }

    // Fetch student profile name
    const profile = await prisma.profile.findUnique({
      where: { userId },
      select: { firstName: true }
    });
    const userName = profile?.firstName || undefined;

    // 3. Generate Response Stream
    const stream = await this.tutorAgent.respond(intent, finalMessages, summary || undefined, userName);

    return { stream, intentCostData, citations: finalCitations };
  }

  async summarizeConversation(messages: CoreMessage[]): Promise<{ summary: string, costData: any }> {
    const systemPrompt = `Summarize the following conversation concisely. Focus on the main topics discussed and any key conclusions. Keep it under 200 words.`;
    
    const result = await this.provider.generate({
      modelName: 'gemini-3.8-flash',
      messages: messages,
      system: systemPrompt,
    });

    return {
      summary: result.text,
      costData: {
        modelName: 'gemini-2.0-flash-lite',
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        requestType: 'SUMMARIZATION',
      }
    };
  }

  async logCost(userId: string, costData: any) {
    const { modelName, promptTokens, completionTokens, requestType } = costData;
    const totalTokens = promptTokens + completionTokens;
    
    // Simple mock cost calculation (e.g. $0.15 per 1M tokens for flash)
    const costPerMillion = modelName.includes('8b') ? 0.05 : 0.15;
    const cost = (totalTokens / 1000000) * costPerMillion;

    await prisma.aiRequestLog.create({
      data: {
        userId,
        modelName,
        promptTokens,
        completionTokens,
        totalTokens,
        cost,
        requestType,
      }
    });
  }
}
