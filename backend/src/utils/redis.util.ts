import Redis, { RedisOptions } from 'ioredis';
import { logger } from './logger';

/**
 * Redis is optional. With REDIS_URL set (production), the document queue, rate
 * limits, locks and caches are shared across all API/worker instances and survive
 * restarts. Without it (local dev), everything falls back to in-process memory.
 */
export const redisEnabled = () => !!process.env.REDIS_URL;

/** Connection options BullMQ requires (blocking commands must not time out). */
export const bullConnectionOptions = (): RedisOptions => ({ maxRetriesPerRequest: null });

let client: Redis | null = null;

/** Shared client for rate limits, locks and caches. null when Redis isn't configured. */
export function getRedis(): Redis | null {
  if (!redisEnabled()) return null;
  if (!client) {
    client = new Redis(process.env.REDIS_URL!, { maxRetriesPerRequest: 2, enableOfflineQueue: true });
    client.on('error', err => logger.error({ err: err.message }, 'Redis error'));
  }
  return client;
}

/** New dedicated connection for BullMQ (it needs its own, with maxRetriesPerRequest: null). */
export const newBullConnection = () => new Redis(process.env.REDIS_URL!, bullConnectionOptions());

export async function closeRedis() {
  if (client) await client.quit().catch(() => {});
  client = null;
}

/**
 * Short-lived mutual exclusion (e.g. one study-plan generation per user at a time).
 * Uses Redis SET NX when available, an in-process Set otherwise.
 */
const localLocks = new Set<string>();
export async function acquireLock(key: string, ttlSeconds: number): Promise<boolean> {
  const redis = getRedis();
  if (redis) return (await redis.set(`lock:${key}`, '1', 'EX', ttlSeconds, 'NX')) === 'OK';
  if (localLocks.has(key)) return false;
  localLocks.add(key);
  setTimeout(() => localLocks.delete(key), ttlSeconds * 1000).unref();
  return true;
}
export async function releaseLock(key: string) {
  const redis = getRedis();
  if (redis) await redis.del(`lock:${key}`);
  else localLocks.delete(key);
}
