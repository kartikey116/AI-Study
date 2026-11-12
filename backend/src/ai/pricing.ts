/**
 * USD per 1M tokens, per model. Set real prices for your models via env so the
 * AiRequestLog.cost column (and any spend dashboard) is accurate:
 *   AI_PRICE_<MODEL>=<input>,<output>   e.g. AI_PRICE_GEMINI_3_8_FLASH=0.10,0.40
 * Unknown models fall back to AI_PRICE_DEFAULT (or 0.15/0.15, the old flat estimate).
 */
function parsePrice(value: string | undefined): { input: number; output: number } | null {
  if (!value) return null;
  const [input, output] = value.split(',').map(Number);
  return Number.isFinite(input) && Number.isFinite(output) ? { input, output } : null;
}

export function priceFor(modelName: string) {
  const envKey = `AI_PRICE_${modelName.toUpperCase().replace(/[^A-Z0-9]+/g, '_')}`;
  return parsePrice(process.env[envKey]) ?? parsePrice(process.env.AI_PRICE_DEFAULT) ?? { input: 0.15, output: 0.15 };
}

/** Providers sometimes omit usage (NaN/undefined); count those as 0 instead of failing the log write. */
export const safeTokens = (n: unknown) => (typeof n === 'number' && Number.isFinite(n) && n > 0 ? Math.round(n) : 0);

export function costUsd(modelName: string, promptTokens: number, completionTokens: number) {
  if (modelName === 'heuristic' || modelName === 'canned') return 0;
  const p = priceFor(modelName);
  return (promptTokens * p.input + completionTokens * p.output) / 1_000_000;
}
