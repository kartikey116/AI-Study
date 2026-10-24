# StudyAI

Flutter app (`app/`) + Express/Prisma/Supabase backend (`backend/`) with Gemini for chat, RAG, quizzes and flashcards.

## Tenant isolation — non-negotiable

No user may ever read, modify, or have the AI use another user's data. When writing or reviewing backend code:

- **Every query on user data filters by `userId`**, directly or through a relation (`deck: { userId }`, `plan: { userId }`, `conversation: { userId }`). Keep the filter even after an ownership check.
- **Never trust a client-supplied id or path.** Use `findFirst({ where: { id, userId } })`, not `findUnique({ where: { id } })`. Verify ownership of `conversationId`, `documentId`, `quizId`, `cardId`, `storagePath`, etc. *before* anything is read, written, or sent to the AI.
- Return **404** for records the user doesn't own (same as "doesn't exist").
- RAG / vector / keyword search is always `userId`-scoped (`backend/src/ai/services/rag.service.ts`).
- Storage paths are `<userId>/<timestamp>-<name>`; the worker downloads with the service-role key, so the prefix check in `routes/documents.ts` is mandatory.
- **Adding an endpoint or table?** Add attack cases to `backend/scripts/test_isolation.ts` and run `npm run test:isolation` (from `backend/`). All checks must pass.

## Backend conventions

- Validate request bodies with zod via `validateBody(schema)` (`src/utils/validation.util.ts`). Anything that reaches an AI prompt must be length-limited.
- Rate limiters live in `src/middleware/rate-limit.middleware.ts`; AI-cost endpoints use `chatLimiter` or `generationLimiter`.
- After `prisma db push`, run `scripts/post_db_push.ts` (done automatically by `npm run prisma:push`): it restores the HNSW/GIN search indexes Prisma drops and enables RLS on every table.
- Embeddings: `gemini-embedding-2` at 768 dims; hybrid search = HNSW vector + GIN full-text merged with RRF.
- Required env: see `backend/.env.example` (the server refuses to start without the JWT secrets).
