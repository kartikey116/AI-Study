import 'dotenv/config'; // must stay first: later imports read process.env at load time
import './instrument';   // error tracking, before the app is loaded
import { app } from './app';
import { assertJwtSecrets } from './utils/jwt.util';
import { logger } from './utils/logger';
import { prisma } from './utils/db.util';
import { closeRedis, redisEnabled } from './utils/redis.util';
import { closeDocumentQueue, recoverStuckDocuments } from './queues/document.queue';

assertJwtSecrets();

const port = Number(process.env.PORT) || 3000;

// Start Server
const server = app.listen(port, '0.0.0.0', () => {
  logger.info({ port, queue: redisEnabled() ? 'bullmq' : 'in-process' }, 'Server is running');

  // In-process mode loses queued jobs on restart; with BullMQ the worker process handles recovery
  if (!redisEnabled()) {
    recoverStuckDocuments().catch(err => logger.error({ err }, 'Stuck-document recovery failed'));
  }
});

// Graceful shutdown: stop accepting requests, let in-flight ones finish, then close connections
let shuttingDown = false;
const shutdown = (signal: string) => {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'Shutting down');
  const force = setTimeout(() => process.exit(1), 25_000);
  force.unref();
  server.close(async () => {
    await Promise.allSettled([closeDocumentQueue(), closeRedis(), prisma.$disconnect()]);
    process.exit(0);
  });
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => logger.error({ err: reason }, 'Unhandled promise rejection'));
