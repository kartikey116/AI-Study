import { CoreMessage, StreamTextResult } from 'ai';

export interface AIProvider {
  /**
   * Generates a streaming response.
   */
  streamGenerate(options: GenerateOptions): Promise<StreamTextResult<any>>;
  
  /**
   * Generates a single text response (useful for fast, internal classification).
   */
  generate(options: GenerateOptions): Promise<{ text: string, promptTokens: number, completionTokens: number }>;
}

export interface GenerateOptions {
  modelName: string;
  messages: CoreMessage[];
  system?: string;
  temperature?: number;
}
