import { CoreMessage } from 'ai';
import { AIProvider } from '../providers/ai-provider.interface';

export enum StudyIntent {
  GENERAL = 'GENERAL',
  CONCEPT_EXPLANATION = 'CONCEPT_EXPLANATION',
  SUMMARIZATION = 'SUMMARIZATION',
  CHAT = 'CHAT',
  RAG_QUERY = 'RAG_QUERY',
}

export class IntentRouter {
  constructor(private provider: AIProvider) { }

  async detectIntent(messages: CoreMessage[]): Promise<{ intent: StudyIntent, costData: any }> {
    const lastMessage = messages[messages.length - 1]?.content as string || '';
    const lower = lastMessage.toLowerCase().trim();

    // Fast heuristic match (0ms latency, saves 3-5 seconds & API tokens)
    if (/^(hi|hello|hey|good\s+(morning|afternoon|evening)|howdy|sup|greetings)[\s!.,?]*$/i.test(lower)) {
      return {
        intent: StudyIntent.CHAT,
        costData: { modelName: 'heuristic', promptTokens: 0, completionTokens: 0, requestType: 'INTENT_DETECTION' }
      };
    }
    if (/^(what is|what are|explain|how does|how do|why is|why does|define|describe|tell me about|difference between|compare)\b/i.test(lower)) {
      return {
        intent: StudyIntent.CONCEPT_EXPLANATION,
        costData: { modelName: 'heuristic', promptTokens: 0, completionTokens: 0, requestType: 'INTENT_DETECTION' }
      };
    }
    if (/^(summarize|summary of|tldr|give me a summary|key takeaways|bullet points of)\b/i.test(lower)) {
      return {
        intent: StudyIntent.SUMMARIZATION,
        costData: { modelName: 'heuristic', promptTokens: 0, completionTokens: 0, requestType: 'INTENT_DETECTION' }
      };
    }

    // We use a highly restrictive system prompt to force a single word output.
    const systemPrompt = `You are an intent router for a study assistant. 
Classify the user's latest message into EXACTLY ONE of the following categories:
- CONCEPT_EXPLANATION: The user is asking to explain a topic, how something works, or to teach them a concept.
- SUMMARIZATION: The user is asking to summarize text, notes, or a long message.
- CHAT: The user is just chatting, saying hello, or making casual conversation.
- RAG_QUERY: The user is asking a question about their notes, documents, uploaded PDFs, or specific text they uploaded.
- GENERAL: Any other study-related query that doesn't fit the above.

Respond with ONLY the exact word of the category. Nothing else.`;

    // Extract only recent context to save tokens on intent detection
    const recentMessages = messages.slice(-3);

    const result = await this.provider.generate({
      // Use fast model for intent routing
      modelName: 'gemini-3.8-flash',
      messages: recentMessages,
      system: systemPrompt,
      temperature: 0.0, // We want deterministic output
    });

    let intent = StudyIntent.GENERAL;
    const text = result.text.trim().toUpperCase();

    if (text.includes(StudyIntent.CONCEPT_EXPLANATION)) intent = StudyIntent.CONCEPT_EXPLANATION;
    else if (text.includes(StudyIntent.SUMMARIZATION)) intent = StudyIntent.SUMMARIZATION;
    else if (text.includes(StudyIntent.CHAT)) intent = StudyIntent.CHAT;
    else if (text.includes(StudyIntent.RAG_QUERY)) intent = StudyIntent.RAG_QUERY;

    return {
      intent,
      costData: {
        modelName: 'gemini-3.8-flash',
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        requestType: 'INTENT_DETECTION',
      }
    };
  }
}
