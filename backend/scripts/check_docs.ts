import { prisma } from '../src/utils/db.util';

async function main() {
  const docs = await prisma.document.findMany({
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      name: true,
      status: true,
      errorMessage: true,
      storagePath: true,
      createdAt: true,
      _count: { select: { chunks: true } }
    }
  });

  console.log('All documents in DB:', JSON.stringify(docs, null, 2));
}

main().finally(() => process.exit());
