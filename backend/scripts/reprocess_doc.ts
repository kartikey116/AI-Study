import 'dotenv/config'; // must stay first
import { prisma } from '../src/utils/db.util';
import { processDocument } from '../src/workers/document.worker';
import { DocumentStatus } from '@prisma/client';

// Re-runs ingestion (text layer + vision, real page numbers) for existing documents.
// Usage:
//   npx ts-node --transpile-only scripts/reprocess_doc.ts <documentId> [<documentId> ...]
//   npx ts-node --transpile-only scripts/reprocess_doc.ts --all
async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.log('Usage: reprocess_doc.ts <documentId...> | --all');
    return;
  }

  const docs = await prisma.document.findMany({
    where: args.includes('--all') ? {} : { id: { in: args } },
    orderBy: { createdAt: 'asc' },
  });
  if (docs.length === 0) {
    console.log('No matching documents.');
    return;
  }

  for (const doc of docs) {
    console.log(`\n=== ${doc.name} (${doc.id}) ===`);
    // Scoped by both ids: only this document's own chunks are removed
    await prisma.documentChunk.deleteMany({ where: { documentId: doc.id, userId: doc.userId } });
    await prisma.document.update({ where: { id: doc.id }, data: { errorMessage: null } });

    try {
      await processDocument({ documentId: doc.id, storagePath: doc.storagePath, userId: doc.userId });
    } catch (err: any) {
      console.error('Processing failed:', err.message);
      await prisma.document.update({
        where: { id: doc.id },
        data: { status: DocumentStatus.FAILED, errorMessage: err.message ?? 'Unknown error' },
      });
    }

    const updated = await prisma.document.findUnique({
      where: { id: doc.id },
      select: { status: true, pageCount: true, errorMessage: true, _count: { select: { chunks: true } } },
    });
    console.log('Result:', { status: updated?.status, pages: updated?.pageCount,
      chunks: updated?._count.chunks, error: updated?.errorMessage ?? undefined });
  }
}

main()
  .catch(err => {
    console.error('Reprocess failed:', err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
