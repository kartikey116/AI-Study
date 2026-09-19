import { prisma } from '../../utils/db.util';
import { embedText } from './embedding.service';

export interface RetrievedChunk {
  id: string;
  documentId: string;
  documentName: string;
  pageNumber: number;
  text: string;
  score: number;
}

export interface Citation {
  chunkId: string;
  documentId: string;
  documentName: string;
  pageNumber: number;
}

/**
 * Hybrid search: combine vector similarity + full-text search.
 * CRITICAL: always scoped by userId — user A never sees user B's data.
 */
export async function retrieveChunks(
  userId: string,
  query: string,
  topK = 8,
  documentId?: string
): Promise<RetrievedChunk[]> {
  // 1. Embed the query
  const queryEmbedding = await embedText(query);
  const vectorStr = `[${queryEmbedding.join(',')}]`;

  // 2. Hybrid search via raw SQL (vector + FTS, userId-scoped)
  let sql = `
    SELECT
      dc.id,
      dc."documentId",
      dc."pageNumber",
      dc.text,
      d.name AS "documentName",
      (0.7 * (1 - (dc.embedding <=> $1::vector)))
      + (0.3 * ts_rank(to_tsvector('english', dc.text), plainto_tsquery('english', $2))) AS score
    FROM "DocumentChunk" dc
    JOIN "Document" d ON d.id = dc."documentId"
    WHERE dc."userId" = $3
      AND dc.embedding IS NOT NULL
      AND d.status = 'READY'
  `;
  
  const params: any[] = [vectorStr, query, userId];
  
  if (documentId) {
    sql += ` AND dc."documentId" = $4 `;
    params.push(documentId);
    sql += ` ORDER BY score DESC LIMIT $5 `;
    params.push(topK);
  } else {
    sql += ` ORDER BY score DESC LIMIT $4 `;
    params.push(topK);
  }

  const rows = await prisma.$queryRawUnsafe<any[]>(sql, ...params);

  return rows.map((r: any) => ({
    id: r.id,
    documentId: r.documentId,
    documentName: r.documentName,
    pageNumber: r.pageNumber,
    text: r.text,
    score: parseFloat(r.score),
  }));
}

/**
 * Rerank using Reciprocal Rank Fusion and return top 3–5 chunks.
 */
export function rerank(chunks: RetrievedChunk[], topN = 5): RetrievedChunk[] {
  return chunks
    .sort((a, b) => b.score - a.score)
    .slice(0, topN);
}

/**
 * Build the context string + citations for the LLM prompt.
 */
export function buildRagContext(chunks: RetrievedChunk[]): {
  contextText: string;
  citations: Citation[];
} {
  if (chunks.length === 0) {
    return {
      contextText: '',
      citations: [],
    };
  }

  const contextParts = chunks.map((c, i) =>
    `[${i + 1}] From "${c.documentName}", Page ${c.pageNumber}:\n${c.text}`
  );

  const contextText = `
=== RELEVANT CONTENT FROM USER'S STUDY MATERIAL ===
${contextParts.join('\n\n')}
===================================================

Use the above content to answer the user's question.
If the content does not contain enough information, say:
"I couldn't find enough information in your uploaded material to answer this confidently."
Always cite the source as: [Document: "{name}", Page {page}].
NEVER invent citations.
`;

  const citations: Citation[] = chunks.map(c => ({
    chunkId: c.id,
    documentId: c.documentId,
    documentName: c.documentName,
    pageNumber: c.pageNumber,
  }));

  return { contextText, citations };
}
