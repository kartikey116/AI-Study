import { retrieveChunks } from '../src/ai/services/rag.service';
import dotenv from 'dotenv';
dotenv.config();

async function main() {
  const userId = '5e21775e-a4c2-42b2-bd26-06ccd76e69b8';
  const docId = 'b35bc6b9-4114-4c04-bf39-094057e6a2cb';

  console.log('Testing retrieveChunks on user document...');
  const chunks = await retrieveChunks(userId, 'Give me summary and core concepts', 5, docId);
  console.log(`Retrieved ${chunks.length} chunks successfully!`);
  for (const c of chunks) {
    console.log(`- Page ${c.pageNumber}, score: ${c.score.toFixed(4)}, text: ${c.text.slice(0, 80)}...`);
  }
}

main().finally(() => process.exit(0));
