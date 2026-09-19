import { embed } from 'ai';
import { google } from '@ai-sdk/google';
import dotenv from 'dotenv';
dotenv.config();

async function run() {
  try {
    const model = google.textEmbeddingModel('gemini-embedding-2');
    const { embedding } = await embed({
      model,
      value: 'Hello world',
    });
    console.log('SUCCESS! gemini-embedding-2 dimensions:', embedding.length);
  } catch (err: any) {
    console.error('Model failed:', err.message);
  }
}

run().then(() => process.exit(0));
