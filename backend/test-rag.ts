import fs from 'fs';

const API_URL = 'http://localhost:3000/api/v1';

async function testRAG() {
  console.log('--- RAG End-to-End Test ---');

  // 1. Create a test user
  console.log('\n1. Registering test user...');
  const email = `test_rag_${Date.now()}@example.com`;
  const registerRes = await fetch(`${API_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'password123', firstName: 'Test', lastName: 'User' })
  });
  const registerData = await registerRes.json();
  const token = registerData.accessToken;
  console.log('User created:', email);

  // 2. Get Signed Upload URL
  console.log('\n2. Requesting signed upload URL...');
  const uploadUrlRes = await fetch(`${API_URL}/documents/upload-url`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ fileName: 'sample.pdf' })
  });
  const uploadUrlData = await uploadUrlRes.json();
  console.log('Signed URL received.');

  // 3. Upload to Supabase Storage
  console.log('\n3. Uploading file to Supabase...');
  const fileBuffer = fs.readFileSync('./sample.pdf');
  const uploadRes = await fetch(uploadUrlData.signedUrl, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/pdf' },
    body: fileBuffer
  });
  if (!uploadRes.ok) throw new Error(`Upload failed: ${await uploadRes.text()}`);
  console.log('File uploaded to Storage.');

  // 4. Confirm upload with Backend
  console.log('\n4. Confirming upload with backend...');
  const confirmRes = await fetch(`${API_URL}/documents`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ 
      storagePath: uploadUrlData.storagePath,
      originalName: 'sample.pdf',
      sizeBytes: fileBuffer.length
    })
  });
  const doc = (await confirmRes.json()).document;
  console.log('Document created:', doc.id);

  // 5. Poll for processing completion
  console.log('\n5. Waiting for processing to complete...');
  let status = 'PROCESSING';
  while (status === 'PROCESSING' || status === 'UPLOADING') {
    await new Promise(r => setTimeout(r, 2000));
    const statusRes = await fetch(`${API_URL}/documents/${doc.id}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const statusData = await statusRes.json();
    status = statusData.document.status;
    console.log(`Status: ${status}...`);
  }

  if (status !== 'READY') {
    throw new Error('Document failed to process!');
  }
  console.log('Document processing complete!');

  // 6. Test RAG Retrieval via Chat
  console.log('\n6. Asking AI Tutor a question about the document...');
  const chatRes = await fetch(`${API_URL}/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ 
      message: 'What does the dummy PDF file say? Use my uploaded documents.',
      documentId: doc.id
    })
  });

  // Read SSE stream
  console.log('\nResponse Stream:');
  const body = await chatRes.text();
  const chunks = body.split('\n\n').filter(Boolean);
  
  let fullResponse = '';
  for (const chunk of chunks) {
    if (chunk.startsWith('data: ')) {
      const data = JSON.parse(chunk.replace('data: ', ''));
      if (data.type === 'meta') {
        console.log('[META]', 'Citations attached:', data.citations?.length || 0);
      } else if (data.type === 'chunk') {
        fullResponse += data.text;
        process.stdout.write(data.text);
      } else if (data.type === 'done') {
        console.log('\n\n[DONE]');
      }
    }
  }

  console.log('\n--- RAG Test Complete ---');
}

testRAG().catch(console.error);
