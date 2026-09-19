import { prisma } from '../src/utils/db.util';
import { processDocument } from '../src/workers/document.worker';

async function main() {
  const docId = 'b35bc6b9-4114-4c04-bf39-094057e6a2cb';
  const doc = await prisma.document.findUnique({ where: { id: docId } });

  if (!doc) {
    console.log('Doc not found');
    return;
  }

  console.log('Deleting existing chunks for doc...');
  await prisma.documentChunk.deleteMany({ where: { documentId: docId } });

  console.log('Processing document:', doc.name, doc.storagePath);
  await processDocument({
    documentId: doc.id,
    storagePath: doc.storagePath,
    userId: doc.userId,
  });

  const updated = await prisma.document.findUnique({
    where: { id: docId },
    include: { _count: { select: { chunks: true } } }
  });

  console.log('Updated document:', updated);
}

main()
  .catch(err => {
    console.error('Reprocess failed:', err);
  })
  .finally(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
