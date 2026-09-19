import { generateText } from 'ai';
import { google } from '@ai-sdk/google';
import dotenv from 'dotenv';
dotenv.config();

async function test(name: string) {
  try {
    const res = await generateText({
      model: google(name),
      prompt: 'Say hello',
    });
    console.log(`[PASS] ${name}: ${res.text.slice(0, 30)}`);
  } catch (err: any) {
    console.log(`[FAIL] ${name}: ${err.message.slice(0, 80)}`);
  }
}

async function main() {
  await test('gemini-2.0-flash');
  await test('gemini-2.5-flash');
  await test('gemini-1.5-flash');
  await test('gemini-2.0-flash-lite');
}

main().finally(() => process.exit(0));
