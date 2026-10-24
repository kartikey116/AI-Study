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
 * Hybrid search: vector similarity + full-text search, fused with RRF.
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

  // 2. Hybrid search via raw SQL (userId-scoped): two independent searches
  //    merged with Reciprocal Rank Fusion, score = Σ 1 / (RRF_K + rank).
  //    a) vector:  top N by embedding distance (HNSW index)
  //    b) keyword: top N by ts_rank_cd (GIN index); query words are OR-ed so
  //       chunks matching only some words still qualify, more matches rank higher
  const candidateLimit = Math.max(topK * 5, 50);
  const RRF_K = 60;
  const params: any[] = [vectorStr, query, userId, candidateLimit, topK, RRF_K];
  const documentFilter = documentId ? `AND dc."documentId" = $7` : '';
  if (documentId) params.push(documentId);

  // to_tsvector('english', dc.text) must match the GIN index expression exactly
  const sql = `
    WITH vector_hits AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY distance) AS rank
      FROM (
        SELECT dc.id, dc.embedding <=> $1::vector AS distance
        FROM "DocumentChunk" dc
        JOIN "Document" d ON d.id = dc."documentId"
        WHERE dc."userId" = $3
          AND dc.embedding IS NOT NULL
          AND d.status = 'READY'
          ${documentFilter}
        ORDER BY dc.embedding <=> $1::vector
        LIMIT $4
      ) v
    ),
    keyword_hits AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY kw_rank DESC) AS rank
      FROM (
        SELECT dc.id, ts_rank_cd(to_tsvector('english', dc.text), q.tsq) AS kw_rank
        FROM "DocumentChunk" dc
        JOIN "Document" d ON d.id = dc."documentId"
        CROSS JOIN (
          SELECT replace(plainto_tsquery('english', $2)::text, '&', '|')::tsquery AS tsq
        ) q
        WHERE dc."userId" = $3
          AND d.status = 'READY'
          AND to_tsvector('english', dc.text) @@ q.tsq
          ${documentFilter}
        ORDER BY kw_rank DESC
        LIMIT $4
      ) k
    ),
    fused AS (
      SELECT id, SUM(1.0 / ($6 + rank)) AS score
      FROM (
        SELECT id, rank FROM vector_hits
        UNION ALL
        SELECT id, rank FROM keyword_hits
      ) hits
      GROUP BY id
    )
    SELECT
      dc.id,
      dc."documentId",
      dc."pageNumber",
      dc.text,
      d.name AS "documentName",
      f.score
    FROM fused f
    JOIN "DocumentChunk" dc ON dc.id = f.id
    JOIN "Document" d ON d.id = dc."documentId"
    ORDER BY f.score DESC
    LIMIT $5
  `;

  // iterative_scan keeps the HNSW scan going when the userId/status filters
  // discard rows, so we still get `candidateLimit` results (pgvector >= 0.8).
  const [, , rows] = await prisma.$transaction([
    prisma.$executeRawUnsafe(`SET LOCAL hnsw.iterative_scan = relaxed_order`),
    prisma.$executeRawUnsafe(`SET LOCAL hnsw.ef_search = 100`),
    prisma.$queryRawUnsafe<any[]>(sql, ...params),
  ]);

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
 * Return the top N chunks by fused RRF score (fusion happens in retrieveChunks).
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
