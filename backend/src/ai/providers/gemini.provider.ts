import { google } from '@ai-sdk/google';
import { generateText, streamText, StreamTextResult } from 'ai';
import { AIProvider, GenerateOptions } from './ai-provider.interface';

export class GeminiProvider implements AIProvider {
  async streamGenerate(options: GenerateOptions): Promise<StreamTextResult<any>> {
    return streamText({
      model: google(options.modelName),
      messages: options.messages,
      system: options.system,
      temperature: options.temperature,
    });
  }

  async generate(options: GenerateOptions): Promise<{ text: string, promptTokens: number, completionTokens: number }> {
    const { text, usage } = await generateText({
      model: google(options.modelName),
      messages: options.messages,
      system: options.system,
      temperature: options.temperature,
    });

    return {
      text,
      promptTokens: usage.promptTokens,
      completionTokens: usage.completionTokens,
    };
  }
}
