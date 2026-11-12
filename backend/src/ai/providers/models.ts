import { google } from '@ai-sdk/google';

/**
 * Single place for model names and Gemini safety settings. Every AI call goes
 * through `geminiModel()` so safety filters can't be forgotten on a new feature.
 * Override model names per environment with env vars (e.g. a cheaper model in staging).
 */
export const MODELS = {
  /** Tutor answers, quiz/flashcard/plan generation, vision transcription */
  main: process.env.GEMINI_MODEL ?? 'gemini-3.8-flash',
  /** Small internal calls: guard/intent classification, query rewriting, reranking, summaries */
  fast: process.env.GEMINI_FAST_MODEL ?? process.env.GEMINI_MODEL ?? 'gemini-3.8-flash',
};

// Dangerous-content uses the gentler threshold: chemistry, biology, history and
// security coursework legitimately discusses hazardous topics.
const SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
] as const;

export const geminiModel = (modelName: string) =>
  google(modelName, { safetySettings: SAFETY_SETTINGS.map(s => ({ ...s })) });
