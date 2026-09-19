import { prisma } from '../src/utils/db.util';

async function main() {
  console.log('Altering embedding column to vector(3072)...');
  try {
    await prisma.$executeRawUnsafe('DROP INDEX IF EXISTS document_chunk_embedding_idx;');
    await prisma.$executeRawUnsafe('ALTER TABLE "DocumentChunk" ALTER COLUMN embedding TYPE vector(3072);');
    console.log('Altered column to vector(3072)!');
  } catch (err: any) {
    console.error('Alter failed:', err.message);
  }

  try {
    console.log('Testing HNSW index on vector(3072)...');
    await prisma.$executeRawUnsafe('CREATE INDEX IF NOT EXISTS document_chunk_embedding_idx ON "DocumentChunk" USING hnsw (embedding vector_cosine_ops);');
    console.log('HNSW index created on vector(3072)!');
  } catch (err: any) {
    console.warn('HNSW on 3072 failed (expected if pgvector limit is 2000):', err.message);
    console.log('Falling back to vector without index or with dimension reduction...');
  }
}

main().finally(() => process.exit());
