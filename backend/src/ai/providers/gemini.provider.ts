import { generateText, streamText, StreamTextResult } from 'ai';
import { AIProvider, GenerateOptions } from './ai-provider.interface';
import { geminiModel } from './models';

export class GeminiProvider implements AIProvider {
  async streamGenerate(options: GenerateOptions): Promise<StreamTextResult<any>> {
    return streamText({
      model: geminiModel(options.modelName),
      messages: options.messages,
      system: options.system,
      temperature: options.temperature,
      abortSignal: options.abortSignal,
    });
  }

  async generate(options: GenerateOptions): Promise<{ text: string, promptTokens: number, completionTokens: number }> {
    const { text, usage } = await generateText({
      model: geminiModel(options.modelName),
      messages: options.messages,
      system: options.system,
      temperature: options.temperature,
      abortSignal: options.abortSignal,
    });

    return {
      text,
      promptTokens: usage.promptTokens,
      completionTokens: usage.completionTokens,
    };
  }
}
