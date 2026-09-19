import { prisma } from '../src/utils/db.util';

async function main() {
  const result = await prisma.document.deleteMany({
    where: {
      name: 'sample.pdf',
      status: { in: ['UPLOADING', 'PROCESSING'] }
    }
  });
  console.log(`Cleaned up ${result.count} stuck sample documents.`);
}

main().finally(() => process.exit());
