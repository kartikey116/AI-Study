import { embed, embedMany } from 'ai';
import { google } from '@ai-sdk/google';

// 768 dims keeps us under pgvector's 2000-dim HNSW limit; gemini-embedding-2
// auto-normalizes truncated outputs, so no manual L2 normalization is needed.
const EMBEDDING_DIMS = 768;
const EMBEDDING_MODEL = google.textEmbeddingModel('gemini-embedding-2', {
  outputDimensionality: EMBEDDING_DIMS,
});

export async function embedText(text: string): Promise<number[]> {
  const { embedding } = await embed({
    model: EMBEDDING_MODEL,
    value: text,
  });
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
