import { getRedis } from './redis.util';
import { logger } from './logger';

/**
 * Small TTL cache: Redis when configured (shared by all instances), otherwise an
 * in-process LRU. Values are JSON.
 *
 * ISOLATION: keys for per-user data MUST include the userId. Only cache values that are
 * a pure function of their key (e.g. the embedding of a text) or are per-user by key.
 */
const MAX_LOCAL_ENTRIES = 2000;
const local = new Map<string, { value: string; expiresAt: number }>();

export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    const redis = getRedis();
    const raw = redis ? await redis.get(key) : localGet(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch (err: any) {
    logger.warn({ err: err.message }, 'Cache read failed');
    return null; // a cache problem must never break the request
  }
}

export async function cacheSet(key: string, value: unknown, ttlSeconds: number): Promise<void> {
  try {
    const raw = JSON.stringify(value);
    const redis = getRedis();
    if (redis) await redis.set(key, raw, 'EX', ttlSeconds);
    else localSet(key, raw, ttlSeconds);
  } catch (err: any) {
    logger.warn({ err: err.message }, 'Cache write failed');
  }
}

function localGet(key: string): string | null {
  const hit = local.get(key);
  if (!hit) return null;
  if (hit.expiresAt < Date.now()) { local.delete(key); return null; }
  local.delete(key); local.set(key, hit); // refresh LRU position
  return hit.value;
}

function localSet(key: string, value: string, ttlSeconds: number) {
  local.delete(key);
  local.set(key, { value, expiresAt: Date.now() + ttlSeconds * 1000 });
  while (local.size > MAX_LOCAL_ENTRIES) local.delete(local.keys().next().value!);
}
