import { prisma } from '../src/utils/db.util';
import { embedBatch, EMBEDDING_DIMS } from '../src/ai/services/embedding.service';

// Migrates DocumentChunk.embedding to vector(768) and adds an HNSW index.
// Safe to re-run: embeds everything first, so a Gemini failure leaves the DB untouched.
async function main() {
  if (EMBEDDING_DIMS !== 768) throw new Error(`EMBEDDING_DIMS is ${EMBEDDING_DIMS}, expected 768`);

  const chunks = await prisma.documentChunk.findMany({ select: { id: true, text: true } });
  console.log(`1. Re-embedding ${chunks.length} chunks at ${EMBEDDING_DIMS} dims...`);
  const embeddings = await embedBatch(chunks.map(c => c.text));
  const bad = embeddings.find(e => e.length !== EMBEDDING_DIMS);
  if (bad) throw new Error(`Gemini returned ${bad.length} dims, expected ${EMBEDDING_DIMS}`);

  console.log('2. Swapping column to vector(768) and writing new embeddings...');
  await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe('DROP INDEX IF EXISTS document_chunk_embedding_idx');
    await tx.$executeRawUnsafe('UPDATE "DocumentChunk" SET embedding = NULL');
    await tx.$executeRawUnsafe(`ALTER TABLE "DocumentChunk" ALTER COLUMN embedding TYPE vector(${EMBEDDING_DIMS})`);
    for (let i = 0; i < chunks.length; i++) {
      await tx.$executeRawUnsafe(
        `UPDATE "DocumentChunk" SET embedding = $1::vector WHERE id = $2`,
        `[${embeddings[i].join(',')}]`,
        chunks[i].id
      );
    }
  }, { timeout: 120_000 });

  console.log('3. Creating HNSW index...');
  await prisma.$executeRawUnsafe(
    'CREATE INDEX IF NOT EXISTS document_chunk_embedding_idx ON "DocumentChunk" USING hnsw (embedding vector_cosine_ops)'
  );

  const check: any = await prisma.$queryRawUnsafe(`
    SELECT
      (SELECT format_type(atttypid, atttypmod) FROM pg_attribute
        WHERE attrelid = '"DocumentChunk"'::regclass AND attname = 'embedding') AS column_type,
      (SELECT COUNT(*)::int FROM "DocumentChunk" WHERE vector_dims(embedding) = ${EMBEDDING_DIMS}) AS chunks_768,
      (SELECT COUNT(*)::int FROM "DocumentChunk" WHERE embedding IS NULL) AS chunks_null,
      (SELECT indexdef FROM pg_indexes WHERE indexname = 'document_chunk_embedding_idx') AS hnsw_index
  `);
  console.log('Done:', check[0]);
}

main()
  .catch(err => {
    console.error('Migration failed:', err.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
