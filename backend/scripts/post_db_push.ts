import { prisma } from '../src/utils/db.util';

// Run after every `prisma db push` (wired into `npm run prisma:push`):
//  1. Prisma can't represent HNSW or expression GIN indexes, so a push drops them.
//  2. Every table in `public` gets Row Level Security with NO policies. The backend
//     connects as the table owner (`postgres`, BYPASSRLS) so it is unaffected, but
//     Supabase's public REST API (anon / authenticated roles) can never read or write
//     rows — even if a future grant or new table would otherwise expose them.
async function main() {
  // Vector search (meaning) — used by the vector_hits stage in rag.service.ts
  await prisma.$executeRawUnsafe(
    'CREATE INDEX IF NOT EXISTS document_chunk_embedding_idx ON "DocumentChunk" USING hnsw (embedding vector_cosine_ops)'
  );
  // Full-text search (keywords) — expression must match rag.service.ts exactly
  await prisma.$executeRawUnsafe(
    `CREATE INDEX IF NOT EXISTS document_chunk_text_fts_idx ON "DocumentChunk" USING gin (to_tsvector('english', text))`
  );
  console.log('Search indexes present: document_chunk_embedding_idx (HNSW), document_chunk_text_fts_idx (GIN).');

  const tables = await prisma.$queryRawUnsafe<{ tbl: string }[]>(
    `SELECT c.relname AS tbl FROM pg_class c
     WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r' AND NOT c.relrowsecurity`
  );
  for (const { tbl } of tables) {
    await prisma.$executeRawUnsafe(`ALTER TABLE public."${tbl.replace(/"/g, '""')}" ENABLE ROW LEVEL SECURITY`);
  }
  console.log(`Row Level Security: enabled on ${tables.length} table(s) that lacked it.`);
}

main()
  .catch(err => {
    console.error('Post-push hardening failed:', err.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
