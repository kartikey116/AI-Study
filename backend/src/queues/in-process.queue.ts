/**
 * In-process async queue with concurrency control.
 * No Redis/BullMQ required. Jobs survive within the Node process lifetime.
 * Each job has exponential backoff on failure (max 3 retries).
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

  constructor(handler: JobHandler<T>, options?: { concurrency?: number; maxRetries?: number }) {
    this.handler = handler;
    this.concurrency = options?.concurrency ?? 2;
    this.maxRetries = options?.maxRetries ?? 3;
  }

  add(id: string, data: T) {
    this.queue.push({ id, data, attempt: 0 });
    console.log(`[Queue] Job added: ${id} (queue size: ${this.queue.length})`);
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
      console.log(`[Queue] Processing job ${job.id} (attempt ${job.attempt + 1})`);
      await this.handler(job.data);
      console.log(`[Queue] Job ${job.id} completed`);
    } catch (err: any) {
      job.attempt++;
      if (job.attempt < this.maxRetries) {
        const delay = Math.pow(2, job.attempt) * 1000; // 2s, 4s, 8s
        console.warn(`[Queue] Job ${job.id} failed (attempt ${job.attempt}). Retrying in ${delay}ms...`, err.message);
        setTimeout(() => {
          this.queue.unshift(job); // push to front for retry
          this.running--;
          this.tick();
        }, delay);
        return;
      } else {
        console.error(`[Queue] Job ${job.id} permanently failed after ${this.maxRetries} attempts`, err);
      }
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
