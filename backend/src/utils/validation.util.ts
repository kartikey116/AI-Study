import { Request, Response, NextFunction } from 'express';
import { z, ZodTypeAny } from 'zod';

// Shared field rules — keep limits here so every route enforces the same bounds.
export const uuid = z.string().uuid();

/** Person names: letters (any language), spaces, apostrophes, dots, hyphens. Max 50. */
export const personName = z
  .string()
  .trim()
  .min(1)
  .max(50)
  .regex(/^[\p{L}\p{M}' .-]+$/u, 'Name may only contain letters, spaces, apostrophes, dots and hyphens');

/** Short free-text labels that end up inside AI prompts (titles, subjects). */
export const promptLabel = z.string().trim().min(1).max(100);

/**
 * Validates req.body against `schema`, replacing it with the parsed (stripped,
 * coerced) value. Unknown keys are dropped, so handlers only see vetted fields.
 */
export const validateBody = (schema: ZodTypeAny) => (req: Request, res: Response, next: NextFunction) => {
  const result = schema.safeParse(req.body ?? {});
  if (!result.success) {
    const message = result.error.errors.map(e => `${e.path.join('.') || 'body'}: ${e.message}`).join('. ');
    return res.status(400).json({ error: message });
  }
  req.body = result.data;
  next();
};
