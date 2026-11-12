import { logger } from '../utils/logger';

/**
 * In-process async queue with concurrency control — the local-dev fallback when
 * REDIS_URL isn't set. Jobs live only as long as the Node process (see
 * recoverStuckDocuments in document.queue.ts). Exponential backoff on failure.
 */

type JobHandler<T> = (data: T) => Promise<void>;

interface Job<T> {
  id: string;
  data: T;
  attempt: number;
}

export class InProcessQueue<T> {
  private queue: Job<T>[] = [];
  private running = 0;
  private handler: JobHandler<T>;
  private concurrency: number;
  private maxRetries: number;
  private onFinalFailure?: (data: T, err: unknown) => unknown;

  constructor(handler: JobHandler<T>, options?: { concurrency?: number; maxRetries?: number; onFinalFailure?: (data: T, err: unknown) => unknown }) {
    this.handler = handler;
    this.concurrency = options?.concurrency ?? 2;
    this.maxRetries = options?.maxRetries ?? 3;
    this.onFinalFailure = options?.onFinalFailure;
  }

  add(id: string, data: T) {
    if (this.queue.some(j => j.id === id)) return; // already queued
    this.queue.push({ id, data, attempt: 0 });
    logger.debug({ jobId: id, queueSize: this.queue.length }, 'Job added');
    this.tick();
  }

  private tick() {
    while (this.running < this.concurrency && this.queue.length > 0) {
      const job = this.queue.shift()!;
      this.running++;
      this.process(job);
    }
  }

  private async process(job: Job<T>) {
    try {
      await this.handler(job.data);
      logger.debug({ jobId: job.id }, 'Job completed');
    } catch (err: any) {
      job.attempt++;
      if (job.attempt < this.maxRetries) {
        const delay = Math.pow(2, job.attempt) * 1000; // 2s, 4s, 8s
        logger.warn({ jobId: job.id, attempt: job.attempt, delay, err: err.message }, 'Job failed, retrying');
        setTimeout(() => {
          this.queue.unshift(job); // push to front for retry
          this.running--;
          this.tick();
        }, delay);
        return;
      }
      await Promise.resolve(this.onFinalFailure?.(job.data, err)).catch(() => {});
    }
    this.running--;
    this.tick();
  }

  get size() {
    return this.queue.length;
  }

  get activeCount() {
    return this.running;
  }
}
