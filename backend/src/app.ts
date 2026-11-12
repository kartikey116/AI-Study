import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { randomUUID } from 'crypto';
import * as Sentry from '@sentry/node';
import chatRouter from './routes/chat';
import authRouter from './routes/auth';
import userRouter from './routes/users';
import quizRoutes from './routes/quiz';
import flashcardRoutes from './routes/flashcard';
import studyRoutes from './routes/study';
import documentsRouter from './routes/documents';
import { authenticate } from './middleware/auth.middleware';
import { apiLimiter } from './middleware/rate-limit.middleware';
import { logger } from './utils/logger';
import { prisma } from './utils/db.util';
import { getRedis } from './utils/redis.util';

export const app = express();

// Behind a reverse proxy (Render, Railway, Cloud Run…) set TRUST_PROXY to the number
// of proxy hops so req.ip is the real client IP and IP rate limits work.
if (process.env.TRUST_PROXY) app.set('trust proxy', Number(process.env.TRUST_PROXY));

// CORS: the mobile app sends no Origin header and is always allowed. Browser origins
// must be listed in CORS_ORIGINS (comma-separated); in production, unlisted origins are refused.
const allowedOrigins = (process.env.CORS_ORIGINS ?? '').split(',').map(o => o.trim()).filter(Boolean);
const allowAnyOrigin = process.env.NODE_ENV !== 'production' && allowedOrigins.length === 0;

// Middleware
app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    callback(null, !origin || allowAnyOrigin || allowedOrigins.includes(origin));
  },
}));

// Request logging with a request id (reuses the client's X-Request-Id if sent, and echoes it back
// so a student's bug report can be matched to server logs). Bodies are never logged.
app.use(pinoHttp({
  logger,
  genReqId: (req, res) => {
    const incoming = req.headers['x-request-id'];
    const id = typeof incoming === 'string' && /^[\w-]{1,100}$/.test(incoming) ? incoming : randomUUID();
    res.setHeader('X-Request-Id', id);
    return id;
  },
  customProps: (req) => ({ userId: (req as Request).userId }),
  customLogLevel: (_req, res, err) => (err || res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info'),
  serializers: {
    req: (req) => ({ id: req.id, method: req.method, url: req.url }),
    res: (res) => ({ statusCode: res.statusCode }),
  },
  autoLogging: { ignore: (req) => req.url === '/health' },
}));

app.use(express.json({ limit: '100kb' }));

// Routes
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/users', authenticate, apiLimiter, userRouter);
app.use('/api/v1/chat', authenticate, apiLimiter, chatRouter);
app.use('/api/v1/documents', authenticate, apiLimiter, documentsRouter);
app.use('/api/v1/quizzes', authenticate, apiLimiter, quizRoutes);
app.use('/api/v1/flashcards', authenticate, apiLimiter, flashcardRoutes);
app.use('/api/v1/study', authenticate, apiLimiter, studyRoutes);

// Liveness: the process is up
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Readiness: dependencies reachable (use for load-balancer / deploy health checks)
app.get('/ready', async (req, res) => {
  const checks: Record<string, 'ok' | 'error'> = {};
  try { await prisma.$queryRaw`SELECT 1`; checks.database = 'ok'; } catch { checks.database = 'error'; }
  const redis = getRedis();
  if (redis) {
    try { await redis.ping(); checks.redis = 'ok'; } catch { checks.redis = 'error'; }
  }
  const ok = Object.values(checks).every(v => v === 'ok');
  res.status(ok ? 200 : 503).json({ status: ok ? 'ready' : 'unavailable', checks });
});

// Sentry captures unhandled route errors (no-op unless SENTRY_DSN is set)
Sentry.setupExpressErrorHandler(app);

// Last-resort error handler: never leak stack traces or internals to clients.
app.use((err: any, req: Request, res: Response, next: NextFunction) => {
  if (res.headersSent) return next(err);
  if (err?.type === 'entity.too.large') return res.status(413).json({ error: 'Request body too large' });
  if (err?.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON body' });
  req.log?.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'Internal Server Error' });
});
