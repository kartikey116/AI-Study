import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import chatRouter from './routes/chat';
import authRouter from './routes/auth';
import userRouter from './routes/users';
import quizRoutes from './routes/quiz';
import flashcardRoutes from './routes/flashcard';
import studyRoutes from './routes/study';
import documentsRouter from './routes/documents';
import { authenticate } from './middleware/auth.middleware';
import { apiLimiter } from './middleware/rate-limit.middleware';

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
app.use(express.json({ limit: '100kb' }));

// Routes
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/users', authenticate, apiLimiter, userRouter);
app.use('/api/v1/chat', authenticate, apiLimiter, chatRouter);
app.use('/api/v1/documents', authenticate, apiLimiter, documentsRouter);
app.use('/api/v1/quizzes', authenticate, apiLimiter, quizRoutes);
app.use('/api/v1/flashcards', authenticate, apiLimiter, flashcardRoutes);
app.use('/api/v1/study', authenticate, apiLimiter, studyRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Last-resort error handler: never leak stack traces or internals to clients.
app.use((err: any, req: Request, res: Response, next: NextFunction) => {
  if (res.headersSent) return next(err);
  if (err?.type === 'entity.too.large') return res.status(413).json({ error: 'Request body too large' });
  if (err?.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON body' });
  console.error('[server] Unhandled error:', err);
  res.status(500).json({ error: 'Internal Server Error' });
});
