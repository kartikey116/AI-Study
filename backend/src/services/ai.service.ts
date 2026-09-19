import { google } from '@ai-sdk/google';
import { streamText, Message } from 'ai';

/**
 * Streams a response from Google Gemini.
 * @param history The conversation history.
 * @param onChunk Callback fired for each text chunk generated.
 */
export async function streamAIResponse(
  history: Message[],
  onChunk: (text: string) => void
): Promise<void> {
  try {
    const result = await streamText({
      model: google('gemini-1.5-flash'),
      messages: history,
      system: `You are an AI Study Companion. You are helpful, encouraging, and clear. 
      You help students understand complex topics, create study plans, and stay focused.
      Format your responses using Markdown. Use lists and bold text to make it easy to read.
      Keep your responses concise but thorough.`,
    });

    for await (const chunk of result.textStream) {
      onChunk(chunk);
    }
  } catch (error) {
    console.error('Error in streamAIResponse:', error);
    onChunk('\n[Error connecting to AI service. Please try again.]');
  }
}
