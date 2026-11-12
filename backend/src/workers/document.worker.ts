import { prisma } from '../utils/db.util';
import { chunkPages } from '../ai/services/chunking.service';
import { createSignedDownloadUrl } from '../utils/supabase.util';
import { embedBatch } from '../ai/services/embedding.service';
import { extractPages, enrichPagesWithVision } from '../ai/services/pdf-extraction.service';
import { MODELS } from '../ai/providers/models';
import { logger } from '../utils/logger';
import { costUsd } from '../ai/pricing';
import { DocumentStatus } from '@prisma/client';

export interface ProcessDocumentJob {
  documentId: string;
  storagePath: string;
  userId: string;
}

export const MAX_PDF_BYTES = 25 * 1024 * 1024; // 25 MB
export const MAX_PDF_PAGES = 300;

// ─── Main Worker Function ──────────────────────────────────────────────────

/** Permanent failure (retrying won't help): mark FAILED with a message the student can act on. */
async function failDocument(documentId: string, errorMessage: string) {
  logger.warn({ documentId, errorMessage }, 'Document rejected');
  await prisma.document.update({
    where: { id: documentId },
    data: { status: DocumentStatus.FAILED, errorMessage },
  });
}

export async function processDocument(job: ProcessDocumentJob): Promise<void> {
  const { documentId, storagePath, userId } = job;

  // 1. Mark as PROCESSING
  await prisma.document.update({
    where: { id: documentId },
    data: { status: DocumentStatus.PROCESSING },
  });

  // 2. Download PDF from Supabase Storage
  const signedUrl = await createSignedDownloadUrl(storagePath);
  const response = await fetch(signedUrl);
  if (!response.ok) throw new Error(`Failed to download PDF: ${response.statusText}`);
  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  logger.info({ documentId, bytes: buffer.length }, 'PDF downloaded');

  if (buffer.length > MAX_PDF_BYTES) {
    return failDocument(documentId, `PDF is too large (max ${MAX_PDF_BYTES / 1024 / 1024} MB).`);
  }
  if (buffer.subarray(0, 5).toString('latin1') !== '%PDF-') {
    return failDocument(documentId, 'This file is not a valid PDF.');
  }

  // 3. Extract the text layer page by page (bounded: never parse more than MAX_PDF_PAGES pages)
  let extracted;
  try {
    extracted = await extractPages(buffer, MAX_PDF_PAGES);
  } catch (err: any) {
    if (err?.name === 'PasswordException') {
      return failDocument(documentId, 'This PDF is password-protected. Please upload an unlocked copy.');
    }
    throw err;
  }

  const { pageCount } = extracted;
  if (pageCount > MAX_PDF_PAGES) {
    return failDocument(documentId, `PDF has too many pages (max ${MAX_PDF_PAGES}).`);
  }

  await prisma.document.update({
    where: { id: documentId },
    data: { pageCount },
  });

  // 4. Vision: transcribe scanned pages, describe diagrams/charts on text pages
  const { pages, usage, scanned, withFigures } = await enrichPagesWithVision(buffer, extracted.pages);
  logger.info({ documentId, pageCount, transcribed: scanned.length, figurePages: withFigures.length, visionRequests: usage.requests }, 'Pages extracted');
  if (usage.requests > 0) {
    await prisma.aiRequestLog.create({
      data: {
        userId,
        modelName: MODELS.main,
        promptTokens: usage.promptTokens,
        completionTokens: usage.completionTokens,
        totalTokens: usage.promptTokens + usage.completionTokens,
        cost: costUsd(MODELS.main, usage.promptTokens, usage.completionTokens),
        requestType: 'DOCUMENT_VISION',
      },
    }).catch(err => logger.warn({ err: err.message }, 'Failed to log vision usage'));
  }

  // 5. Chunk (structure-aware: paragraphs, headings, sentence boundaries)
  const chunks = chunkPages(pages);

  // Don't report READY when nothing is searchable (blank or unreadable PDF)
  if (chunks.length === 0) {
    return failDocument(documentId, 'No readable content found in this PDF. It may be blank or unreadable.');
  }

  // 6. Deduplicate within this document only. Re-runs (retries, reprocessing) skip chunks
  //    already stored; other documents never affect this one.
  const existingHashes = await prisma.documentChunk.findMany({
    where: {
      userId,
      documentId,
      contentHash: { in: chunks.map(c => c.contentHash) },
    },
    select: { contentHash: true },
  });
  const seen = new Set(existingHashes.map(r => r.contentHash));
  const newChunks = chunks.filter(c => {
    if (seen.has(c.contentHash)) return false;
    seen.add(c.contentHash); // also drops repeated text inside this document (headers, footers)
    return true;
  });

  logger.info({ documentId, chunks: chunks.length, toEmbed: newChunks.length }, 'Chunks ready to embed');

  // 7. Batch embed new chunks
  const embeddings = await embedBatch(newChunks.map(c => c.text));

  // 8. Insert chunks in batches: one statement per 100 chunks, vectors included
  //    (ids generated in SQL; previously 2 round-trips per chunk)
  const INSERT_BATCH = 100;
  for (let i = 0; i < newChunks.length; i += INSERT_BATCH) {
    const batch = newChunks.slice(i, i + INSERT_BATCH);
    await prisma.$executeRawUnsafe(
      `INSERT INTO "DocumentChunk" (id, "documentId", "userId", "pageNumber", "chunkIndex", text, "contentHash", embedding, "createdAt", "updatedAt")
       SELECT gen_random_uuid()::text, $1, $2, u.page, u.idx, u.body, u.hash, u.vec::vector, now(), now()
       FROM unnest($3::int[], $4::int[], $5::text[], $6::text[], $7::text[]) AS u(page, idx, body, hash, vec)`,
      documentId,
      userId,
      batch.map(c => c.pageNumber),
      batch.map(c => c.chunkIndex),
      batch.map(c => c.text),
      batch.map(c => c.contentHash),
      batch.map((_, j) => `[${embeddings[i + j].join(',')}]`),
    );
  }

  // 9. Mark READY
  await prisma.document.update({
    where: { id: documentId },
    data: { status: DocumentStatus.READY },
  });

  logger.info({ documentId, chunks: newChunks.length }, 'Document READY');
}
