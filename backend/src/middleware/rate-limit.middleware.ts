import { Request } from 'express';
import { rateLimit, ipKeyGenerator } from 'express-rate-limit';

// In-memory store: correct for a single server instance. When running more than
// one instance, switch to a shared store (e.g. rate-limit-redis) so limits hold globally.

/** Authenticated routes are limited per user; anything else per client IP. */
const userOrIpKey = (req: Request) => req.userId ?? ipKeyGenerator(req.ip ?? '');

const limiter = (windowMs: number, limit: number, message: string, keyGenerator = userOrIpKey) =>
  rateLimit({
    windowMs,
    limit,
    keyGenerator,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    message: { error: message },
  });

/** Login/register: slows down password guessing and account spam. */
export const authLimiter = limiter(15 * 60_000, 10, 'Too many attempts. Please try again in 15 minutes.',
  (req) => ipKeyGenerator(req.ip ?? ''));

/** Token refresh: generous, but bounded. */
export const refreshLimiter = limiter(15 * 60_000, 60, 'Too many requests. Please try again later.',
  (req) => ipKeyGenerator(req.ip ?? ''));

/** Baseline for every authenticated API route. */
export const apiLimiter = limiter(15 * 60_000, 300, 'Too many requests. Please slow down.');

/** Tutor chat — each message costs 2 LLM calls. */
export const chatLimiter = limiter(60_000, 20, 'You are sending messages too quickly. Please wait a moment.');

/** Expensive AI generation: quizzes, flashcard decks, study plans, document ingestion. */
export const generationLimiter = limiter(60 * 60_000, 30, 'Generation limit reached. Please try again later.');
