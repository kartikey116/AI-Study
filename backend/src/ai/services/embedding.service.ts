import { embed, embedMany } from 'ai';
import { google } from '@ai-sdk/google';
import { createHash } from 'crypto';
import { cacheGet, cacheSet } from '../../utils/cache.util';

// 768 dims keeps us under pgvector's 2000-dim HNSW limit; gemini-embedding-2
// auto-normalizes truncated outputs, so no manual L2 normalization is needed.
const EMBEDDING_DIMS = 768;
const EMBEDDING_MODEL_ID = 'gemini-embedding-2';
const EMBEDDING_MODEL = google.textEmbeddingModel(EMBEDDING_MODEL_ID, {
  outputDimensionality: EMBEDDING_DIMS,
});
const QUERY_CACHE_TTL = 7 * 24 * 60 * 60; // embeddings are deterministic; a week is safe

/**
 * Embeds a search query. Cached by content hash: the embedding is a pure function of the
 * text (no user data in the value), so repeated questions skip the API call.
 */
export async function embedText(text: string): Promise<number[]> {
  const key = `emb:${EMBEDDING_MODEL_ID}:${EMBEDDING_DIMS}:${createHash('sha256').update(text).digest('hex')}`;
  const cached = await cacheGet<number[]>(key);
  if (cached) return cached;

  const { embedding } = await embed({
    model: EMBEDDING_MODEL,
    value: text,
  });
  await cacheSet(key, embedding, QUERY_CACHE_TTL);
  return embedding;
}

export async function embedBatch(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return [];

  // Gemini allows up to 100 texts per batch call
  const BATCH_SIZE = 100;
  const allEmbeddings: number[][] = [];

  for (let i = 0; i < texts.length; i += BATCH_SIZE) {
    const batch = texts.slice(i, i + BATCH_SIZE);
    const { embeddings } = await embedMany({
      model: EMBEDDING_MODEL,
      values: batch,
    });
    allEmbeddings.push(...embeddings);
  }

  return allEmbeddings;
}

export { EMBEDDING_DIMS };
