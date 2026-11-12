# Deploying StudyAI backend

## What runs in production

| Process | Command | Notes |
|---|---|---|
| API | `node dist/index.js` (Docker default) | Stateless; run 2+ instances behind a load balancer |
| Worker | `node dist/worker.js` | PDF parsing, vision, embeddings. Needs `REDIS_URL` |
| Redis | managed (Upstash, Redis Cloud, ElastiCache) | Queue, shared rate limits, locks, cache. Enable persistence |
| Postgres + Storage | Supabase | pgvector, RLS on every table, private `study-documents` bucket |

One Docker image serves both processes (`backend/Dockerfile`). `docker compose up --build` in `backend/` runs API + worker + Redis locally against your Supabase project.

## Environments
- **Staging**: a separate Supabase project + Redis + Gemini key. Deploy every merge to `main` there first.
- **Production**: promote the same image tag after staging checks pass.
- Never share a database, bucket, Redis or JWT secrets between staging and production.

## Secrets
Store in the host's secret manager (Render/Railway env groups, GCP Secret Manager, AWS Secrets Manager), never in the repo. Required: `DATABASE_URL`, `DIRECT_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `REDIS_URL`. Production: `NODE_ENV=production`, `TRUST_PROXY` (proxy hops), `CORS_ORIGINS` (only if a web client exists). See `backend/.env.example` for all settings.

Rotating `JWT_*` logs every user out. Rotating the Supabase service key requires redeploying API and worker.

## Schema changes
Run from CI or a deploy machine (not at container start), against staging first:
```bash
cd backend && npm ci && npm run prisma:push   # db push + HNSW/GIN indexes + RLS
```
Never run plain `npx prisma db push`: it drops the HNSW index (restore with `npx ts-node --transpile-only scripts/post_db_push.ts`).

## Health checks
- `GET /health`: liveness (process up). Use for restarts.
- `GET /ready`: database (+ Redis) reachable, 503 otherwise. Use for load-balancer routing and deploy gates.

## Backups & recovery
- Supabase: enable **Point-in-Time Recovery** (Pro add-on) on production; daily backups are included on Pro. Test a restore into staging once per quarter.
- Storage: the bucket is not covered by database backups. Keep the bucket's own backup/replication policy, or periodically copy it to another bucket.
- Redis holds only transient data (queued jobs, counters, cache). If it's lost, the worker's periodic sweep re-queues documents stuck in `PROCESSING`.

## Monitoring
- Logs are JSON (pino) with `requestId`, `userId`, `documentId`; ship them to your log platform. Clients can send `X-Request-Id`, which is echoed back.
- Errors go to Sentry when `SENTRY_DSN` is set (request bodies stripped).
- Spend: `AiRequestLog` has per-request tokens and cost by `requestType`. Set real `AI_PRICE_*` values.

## Checks before every release
```bash
cd backend
npx tsc --noEmit -p .
npm run test:isolation     # tenant isolation, no AI calls (runs in CI on every push)
npm run test:guardrails    # AI red-team suite, real Gemini calls (CI: manual "Run workflow")
npm run eval:retrieval -- --rerank   # after changing models, chunking or retrieval (needs npm run eval:build once)
```
