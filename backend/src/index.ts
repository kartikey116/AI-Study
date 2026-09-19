import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import chatRouter from './routes/chat';
import authRouter from './routes/auth';
import userRouter from './routes/users';
import quizRoutes from './routes/quiz';
import flashcardRoutes from './routes/flashcard';
import studyRoutes from './routes/study';

dotenv.config();

const app = express();
const port = Number(process.env.PORT) || 3000;

// Middleware
app.use(cors());
app.use(express.json());

import documentsRouter from './routes/documents';
import { authenticate } from './middleware/auth.middleware';

// Routes
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/users', authenticate, userRouter);
app.use('/api/v1/chat', authenticate, chatRouter);
app.use('/api/v1/documents', authenticate, documentsRouter);
app.use('/api/v1/quizzes', authenticate, quizRoutes);
app.use('/api/v1/flashcards', authenticate, flashcardRoutes);
app.use('/api/v1/study', authenticate, studyRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', environment: process.env.NODE_ENV });
});

// Start Server
app.listen(port, '0.0.0.0', () => {
  console.log(`[server]: Server is running at http://0.0.0.0:${port}`);
});
