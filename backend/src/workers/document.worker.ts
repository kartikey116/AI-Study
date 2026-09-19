import * as crypto from 'crypto';
import fs from 'fs';
import pdfParse = require('pdf-parse');
import { prisma } from '../utils/db.util';
import { createSignedDownloadUrl } from '../utils/supabase.util';
import { embedBatch } from '../ai/services/embedding.service';
import { InProcessQueue } from '../queues/in-process.queue';
import { DocumentStatus } from '@prisma/client';

export interface ProcessDocumentJob {
  documentId: string;
  storagePath: string;
  userId: string;
}

const CHUNK_SIZE = 400;    // target tokens per chunk (~1600 chars)
const CHUNK_OVERLAP = 50;  // overlap in tokens (~200 chars)
const CHARS_PER_TOKEN = 4;

// ─── Chunking ──────────────────────────────────────────────────────────────

interface TextChunk {
  text: string;
  pageNumber: number;
  chunkIndex: number;
  contentHash: string;
}

function chunkText(pages: { text: string; pageNumber: number }[]): TextChunk[] {
  const chunks: TextChunk[] = [];
  let chunkIndex = 0;

  for (const page of pages) {
    const words = page.text.split(/\s+/).filter(Boolean);
    const chunkWords = CHUNK_SIZE * CHARS_PER_TOKEN / 5; // approx words per chunk
    const overlapWords = CHUNK_OVERLAP * CHARS_PER_TOKEN / 5;

    let start = 0;
    while (start < words.length) {
      const end = Math.min(start + chunkWords, words.length);
      const text = words.slice(start, end).join(' ').trim();

      if (text.length > 50) { // skip tiny chunks
        const contentHash = crypto.createHash('sha256').update(text).digest('hex');
        chunks.push({
          text,
          pageNumber: page.pageNumber,
          chunkIndex: chunkIndex++,
          contentHash,
        });
      }

      if (end >= words.length) break;
      start = Math.max(start + 1, end - overlapWords);
    }
  }

  return chunks;
}

// ─── Main Worker Function ──────────────────────────────────────────────────

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
  console.log(`[Worker] PDF downloaded, size: ${buffer.length}`);

  // 3. Extract text per page
  console.log(`[Worker] Starting pdfParse...`);
  const parsed = await pdfParse(buffer, {
    max: 0,
    // Extract page-by-page
    pagerender: async (pageData: any) => {
      const textContent = await pageData.getTextContent();
      return textContent.items.map((item: any) => item.str).join(' ');
    }
  });
  console.log(`[Worker] pdfParse complete, extracted ${parsed.text.length} chars`);

  const pageCount = parsed.numpages;

  // Build per-page text array  
  const fullText = parsed.text;
  const estimatedCharsPerPage = Math.ceil(fullText.length / Math.max(pageCount, 1));
  
  const pages = Array.from({ length: pageCount }, (_, i) => ({
    pageNumber: i + 1,
    text: fullText.slice(i * estimatedCharsPerPage, (i + 1) * estimatedCharsPerPage),
  }));

  // Update page count
  await prisma.document.update({
    where: { id: documentId },
    data: { pageCount },
  });

  // 4. Chunk
  const chunks = chunkText(pages);
  console.log(`[Worker] Document ${documentId}: ${pageCount} pages, ${chunks.length} chunks`);

  // 5. Deduplicate by content hash
  const existingHashes = await prisma.documentChunk.findMany({
    where: {
      userId,
      contentHash: { in: chunks.map(c => c.contentHash) },
    },
    select: { contentHash: true },
  });
  const existingHashSet = new Set(existingHashes.map(r => r.contentHash));
  const newChunks = chunks.filter(c => !existingHashSet.has(c.contentHash));

  console.log(`[Worker] New chunks to embed: ${newChunks.length} (${existingHashSet.size} deduped)`);

  // 6. Batch embed new chunks
  const embeddings = await embedBatch(newChunks.map(c => c.text));

  // 7. Insert chunks into DB (prisma for metadata, raw SQL for vector column)
  for (let i = 0; i < newChunks.length; i++) {
    const chunk = newChunks[i];
    const embedding = embeddings[i];

    // Insert chunk record first
    const created = await prisma.documentChunk.create({
      data: {
        documentId,
        userId,
        pageNumber: chunk.pageNumber,
        chunkIndex: chunk.chunkIndex,
        text: chunk.text,
        contentHash: chunk.contentHash,
      },
    });

    // Update embedding via raw SQL (pgvector)
    const vectorStr = `[${embedding.join(',')}]`;
    await prisma.$executeRawUnsafe(
      `UPDATE "DocumentChunk" SET embedding = $1::vector WHERE id = $2`,
      vectorStr,
      created.id
    );
  }

  // 8. Mark READY
  await prisma.document.update({
    where: { id: documentId },
    data: { status: DocumentStatus.READY },
  });

  console.log(`[Worker] Document ${documentId} is READY`);
}

// ─── Export the Queue Singleton ────────────────────────────────────────────

export const documentQueue = new InProcessQueue<ProcessDocumentJob>(
  async (job) => {
    try {
      await processDocument(job);
    } catch (err: any) {
      console.error(`[Worker] Processing failed for ${job.documentId}:`, err);
      await prisma.document.update({
        where: { id: job.documentId },
        data: {
          status: DocumentStatus.FAILED,
          errorMessage: err.message ?? 'Unknown error',
        },
      }).catch(() => {}); // don't throw if DB also fails
      throw err; // re-throw so the queue can retry
    }
  },
  { concurrency: 2, maxRetries: 3 }
);
