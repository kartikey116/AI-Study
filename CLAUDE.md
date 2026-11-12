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
- PDF ingestion (`src/ai/services/pdf-extraction.service.ts`): text layer per page via pdf-parse (`getTextContent` only — pdf.js display APIs like `getOperatorList` need browser `document`/`Image` and **crash the Node process**); figure-image detection via pdf-lib structure (nothing decoded); scanned pages transcribed and figures described by Gemini vision. Reprocess existing docs with `scripts/reprocess_doc.ts <id...> | --all`.
- Required env: see `backend/.env.example` (the server refuses to start without the JWT secrets).

## AI guardrails

- Every chat message goes through the guard classifier (`src/ai/routers/intent.router.ts`) first; non-STUDY verdicts get a fixed reply from `REFUSALS` and never reach retrieval or the tutor.
- Untrusted text (PDF passages, summaries, user-typed titles/subjects) goes in the **user** turn via `wrapUntrusted(tag, text)` (`src/ai/guards/prompt-safety.ts`), never in a system prompt. Gemini also rejects system messages after the first turn.
- All model calls use `geminiModel(MODELS.main | MODELS.fast)` (`src/ai/providers/models.ts`) so safety settings apply. Topic-only quiz/deck/plan generation calls `checkStudyTopic` first.
- Changing prompts or the classifier? Run `npm run test:guardrails` (real Gemini calls).

## Infrastructure

- `REDIS_URL` set → BullMQ queue + separate worker (`npm run worker`), Redis rate limits/locks/cache. Unset → in-process fallback for local dev.
- Log with `logger` (`src/utils/logger.ts`, pino): ids and counts only — never message text, document content or tokens.
- Retrieval: RRF hybrid → LLM rerank (`rerank.service.ts`, on unless `RERANK_ENABLED=false`) → top 4. Chunking: `chunking.service.ts`. After changing either, run `npm run eval:retrieval -- --rerank` and compare.
- Deployment, backups and release checks: `docs/DEPLOYMENT.md`.
