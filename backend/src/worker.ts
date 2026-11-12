import 'dotenv/config'; // must stay first
process.env.SERVICE_NAME ??= 'studyai-worker';
import './instrument';
import { logger } from './utils/logger';
import { prisma } from './utils/db.util';
import { closeRedis, redisEnabled } from './utils/redis.util';
import { startDocumentWorker, recoverStuckDocuments, closeDocumentQueue } from './queues/document.queue';

// Document-processing worker (PDF parsing, vision, embeddings). Runs as its own process
// so heavy PDFs never slow down the API:  npm run worker   (requires REDIS_URL)
if (!redisEnabled()) {
  logger.error('REDIS_URL is not set. Without Redis, documents are processed inside the API process; no worker needed.');
  process.exit(1);
}

const worker = startDocumentWorker();
logger.info({ concurrency: worker.opts.concurrency }, 'Document worker started');

recoverStuckDocuments().catch(err => logger.error({ err }, 'Stuck-document recovery failed'));
// Periodic sweep in case a job was lost (e.g. Redis data loss)
const sweep = setInterval(() => recoverStuckDocuments().catch(() => {}), 15 * 60_000);

const shutdown = async (signal: string) => {
  logger.info({ signal }, 'Worker shutting down (finishing active jobs)');
  clearInterval(sweep);
  const force = setTimeout(() => process.exit(1), 60_000);
  force.unref();
  await worker.close(); // waits for in-flight jobs
  await Promise.allSettled([closeDocumentQueue(), closeRedis(), prisma.$disconnect()]);
  process.exit(0);
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
