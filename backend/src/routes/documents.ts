import { Router, Request, Response } from 'express';
import { prisma } from '../utils/db.util';
import { createSignedUploadUrl, deleteStorageFile } from '../utils/supabase.util';
import { documentQueue } from '../workers/document.worker';
import { DocumentStatus } from '@prisma/client';

const router = Router();

// ── GET /documents — list user's documents ────────────────────────────────
router.get('/', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const documents = await prisma.document.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        originalName: true,
        status: true,
        pageCount: true,
        sizeBytes: true,
        mimeType: true,
        errorMessage: true,
        createdAt: true,
        _count: { select: { chunks: true } },
      },
    });
    res.json({ documents });
  } catch (err) {
    res.status(500).json({ error: 'Failed to list documents' });
  }
});

// ── POST /documents/upload-url — get signed upload URL ────────────────────
router.post('/upload-url', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { fileName, mimeType = 'application/pdf' } = req.body;

    if (!fileName) return res.status(400).json({ error: 'fileName is required' });
    if (mimeType !== 'application/pdf') {
      return res.status(400).json({ error: 'Only PDF files are supported' });
    }

    // Build storage path: userId/timestamp-filename
    const sanitized = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
    const storagePath = `${userId}/${Date.now()}-${sanitized}`;

    const { signedUrl, token } = await createSignedUploadUrl(storagePath);

    res.json({ signedUrl, storagePath, token });
  } catch (err: any) {
    console.error('[Documents] upload-url error:', err);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// ── POST /documents — confirm upload, create record, queue processing ────
router.post('/', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { storagePath, originalName, sizeBytes } = req.body;

    if (!storagePath || !originalName) {
      return res.status(400).json({ error: 'storagePath and originalName are required' });
    }

    const doc = await prisma.document.create({
      data: {
        userId,
        name: originalName,
        originalName,
        storagePath,
        mimeType: 'application/pdf',
        sizeBytes: sizeBytes ?? 0,
        status: DocumentStatus.PROCESSING,
      },
    });

    // Enqueue processing job
    documentQueue.add(doc.id, {
      documentId: doc.id,
      storagePath: doc.storagePath,
      userId,
    });

    res.status(201).json({ document: doc });
  } catch (err: any) {
    console.error('[Documents] create error:', err);
    res.status(500).json({ error: 'Failed to create document' });
  }
});

// ── GET /documents/:id — document detail ─────────────────────────────────
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const doc = await prisma.document.findFirst({
      where: { id: req.params.id, userId }, // userId-scoped
      include: {
        _count: { select: { chunks: true } },
      },
    });
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    res.json({ document: doc });
  } catch (err) {
    res.status(500).json({ error: 'Failed to get document' });
  }
});

// ── GET /documents/:id/status — SSE status updates ───────────────────────
router.get('/:id/status', async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const documentId = req.params.id;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  const send = (data: object) => res.write(`data: ${JSON.stringify(data)}\n\n`);

  const poll = setInterval(async () => {
    try {
      const doc = await prisma.document.findFirst({
        where: { id: documentId, userId },
        select: { status: true, pageCount: true, errorMessage: true },
      });

      if (!doc) {
        send({ error: 'not_found' });
        clearInterval(poll);
        res.end();
        return;
      }

      send({ status: doc.status, pageCount: doc.pageCount, errorMessage: doc.errorMessage });

      if (doc.status === DocumentStatus.READY || doc.status === DocumentStatus.FAILED) {
        clearInterval(poll);
        setTimeout(() => res.end(), 500);
      }
    } catch (err) {
      clearInterval(poll);
      res.end();
    }
  }, 2000);

  req.on('close', () => clearInterval(poll));
});

// ── DELETE /documents/:id ─────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const doc = await prisma.document.findFirst({
      where: { id: req.params.id, userId },
    });
    if (!doc) return res.status(404).json({ error: 'Document not found' });

    // Delete chunks first (cascade should handle, but be explicit)
    await prisma.documentChunk.deleteMany({ where: { documentId: doc.id } });
    await prisma.document.delete({ where: { id: doc.id } });

    // Delete from storage
    await deleteStorageFile(doc.storagePath).catch(err =>
      console.warn('[Documents] Storage delete failed (non-fatal):', err.message)
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete document' });
  }
});

export default router;
