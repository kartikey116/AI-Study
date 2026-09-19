import { prisma } from '../src/utils/db.util';

async function main() {
  console.log('--- Setting up pgvector extension & DocumentChunk.embedding column ---');
  
  try {
    console.log('1. Enabling vector extension...');
    await prisma.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS vector;');
    console.log('Vector extension enabled successfully!');
  } catch (err: any) {
    console.error('Failed to enable vector extension:', err.message);
  }

  try {
    console.log('2. Adding embedding column to DocumentChunk table...');
    await prisma.$executeRawUnsafe('ALTER TABLE "DocumentChunk" ADD COLUMN IF NOT EXISTS embedding vector(768);');
    console.log('Column "embedding" added successfully!');
    await prisma.$executeRawUnsafe('CREATE INDEX IF NOT EXISTS document_chunk_embedding_idx ON "DocumentChunk" USING hnsw (embedding vector_cosine_ops);');
    console.log('HNSW index created on embedding!');
  } catch (err: any) {
    console.error('Failed to add embedding column or index:', err.message);
  }

  try {
    console.log('3. Checking DocumentChunk columns...');
    const columns: any = await prisma.$queryRawUnsafe(`
      SELECT column_name, data_type, udt_name 
      FROM information_schema.columns 
      WHERE table_name = 'DocumentChunk';
    `);
    console.log('DocumentChunk columns:', columns);
  } catch (err: any) {
    console.error('Failed to query columns:', err.message);
  }

  try {
    console.log('4. Resetting FAILED documents to UPLOADING so they can be re-processed...');
    const result = await prisma.document.updateMany({
      where: { status: 'FAILED' },
      data: { status: 'UPLOADING', errorMessage: null }
    });
    console.log(`Reset ${result.count} failed documents.`);
  } catch (err: any) {
    console.error('Failed to reset documents:', err.message);
  }

  console.log('--- Done! ---');
}

main()
  .catch(console.error)
  .finally(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
