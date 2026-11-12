import { Queue, Worker, Job } from 'bullmq';
import * as Sentry from '@sentry/node';
import { DocumentStatus } from '@prisma/client';
import { prisma } from '../utils/db.util';
import { logger } from '../utils/logger';
import { redisEnabled, newBullConnection } from '../utils/redis.util';
import { InProcessQueue } from './in-process.queue';
import { processDocument, ProcessDocumentJob } from '../workers/document.worker';

/**
 * Document ingestion queue.
 *  - REDIS_URL set (production): BullMQ. Jobs persist across restarts and are processed by
 *    the separate worker process (`npm run worker`), so PDF parsing never slows the API.
 *  - No Redis (local dev): in-process queue inside the API, same behavior as before.
 */
const QUEUE_NAME = 'document-processing';
const ATTEMPTS = 3;

async function markFailed(documentId: string, err: unknown) {
  await prisma.document.update({
    where: { id: documentId },
    data: { status: DocumentStatus.FAILED, errorMessage: (err as any)?.message ?? 'Unknown error' },
  }).catch(() => {}); // don't throw if the document was deleted meanwhile
}

let bullQueue: Queue<ProcessDocumentJob> | null = null;
const getBullQueue = () => (bullQueue ??= new Queue<ProcessDocumentJob>(QUEUE_NAME, { connection: newBullConnection() }));

const inProcess = new InProcessQueue<ProcessDocumentJob>(
  (job) => processDocument(job),
  {
    concurrency: 2,
    maxRetries: ATTEMPTS,
    onFinalFailure: (job, err) => {
      logger.error({ documentId: job.documentId, err }, 'Document processing permanently failed');
      Sentry.captureException(err, { tags: { documentId: job.documentId } });
      return markFailed(job.documentId, err);
    },
  }
);

export async function enqueueDocument(job: ProcessDocumentJob) {
  if (!redisEnabled()) return inProcess.add(job.documentId, job);
  await getBullQueue().add('process', job, {
    jobId: job.documentId, // de-duplicates double submits / recovery re-enqueues
    attempts: ATTEMPTS,
    backoff: { type: 'exponential', delay: 5_000 },
    removeOnComplete: true,
    removeOnFail: true, // the failure is recorded on the Document row
  });
}

/**
 * Re-queues documents stuck in PROCESSING (e.g. the server restarted mid-job).
 * In-process mode loses every queued job on restart, so all PROCESSING docs are re-queued at
 * API start; with BullMQ only ones idle for `staleMinutes` (jobId de-dupes live jobs anyway).
 */
export async function recoverStuckDocuments(staleMinutes = redisEnabled() ? 30 : 0) {
  const stuck = await prisma.document.findMany({
    where: { status: DocumentStatus.PROCESSING, updatedAt: { lt: new Date(Date.now() - staleMinutes * 60_000) } },
    select: { id: true, storagePath: true, userId: true },
  });
  for (const d of stuck) await enqueueDocument({ documentId: d.id, storagePath: d.storagePath, userId: d.userId });
  if (stuck.length) logger.warn({ count: stuck.length }, 'Re-queued documents stuck in PROCESSING');
  return stuck.length;
}

/** BullMQ worker — runs only in the worker process. */
export function startDocumentWorker(concurrency = Number(process.env.WORKER_CONCURRENCY ?? 2)) {
  const worker = new Worker<ProcessDocumentJob>(
    QUEUE_NAME,
    async (job: Job<ProcessDocumentJob>) => {
      logger.info({ documentId: job.data.documentId, attempt: job.attemptsMade + 1 }, 'Processing document');
      await processDocument(job.data);
    },
    { connection: newBullConnection(), concurrency, lockDuration: 10 * 60_000 }
  );

  worker.on('failed', (job, err) => {
    if (!job) return;
    const final = job.attemptsMade >= (job.opts.attempts ?? 1);
    logger.warn({ documentId: job.data.documentId, attempt: job.attemptsMade, final, err: err.message }, 'Document job failed');
    if (final) {
      Sentry.captureException(err, { tags: { documentId: job.data.documentId } });
      markFailed(job.data.documentId, err);
    }
  });
  worker.on('error', err => logger.error({ err: err.message }, 'Worker error'));
  return worker;
}

export async function closeDocumentQueue() {
  if (bullQueue) await bullQueue.close();
  bullQueue = null;
}
