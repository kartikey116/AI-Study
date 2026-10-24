import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/db.util';
import { createSignedUploadUrl, deleteStorageFile, getStorageFileInfo } from '../utils/supabase.util';
import { validateBody } from '../utils/validation.util';
import { generationLimiter } from '../middleware/rate-limit.middleware';
import { documentQueue, MAX_PDF_BYTES } from '../workers/document.worker';
import { DocumentStatus } from '@prisma/client';

const router = Router();

const uploadUrlSchema = z.object({
  fileName: z.string().trim().min(1).max(200),
  mimeType: z.literal('application/pdf').default('application/pdf'),
});

const confirmUploadSchema = z.object({
  storagePath: z.string().max(300),
  originalName: z.string().trim().min(1).max(255),
});

/** The only path shape /upload-url ever hands out: `<userId>/<timestamp>-<sanitized name>`. */
const isOwnStoragePath = (userId: string, storagePath: string) =>
  storagePath.startsWith(`${userId}/`) && /^[0-9a-f-]{36}\/\d+-[a-zA-Z0-9._-]+$/.test(storagePath)
  && !storagePath.includes('..');

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
router.post('/upload-url', validateBody(uploadUrlSchema), async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { fileName } = req.body as z.infer<typeof uploadUrlSchema>;

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
router.post('/', generationLimiter, validateBody(confirmUploadSchema), async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { storagePath, originalName } = req.body as z.infer<typeof confirmUploadSchema>;

    // ISOLATION: the worker downloads with the service-role key, so a client-supplied
    // path must be inside this user's own folder — otherwise anyone could ingest another
    // user's PDF into their account.
    if (!isOwnStoragePath(userId, storagePath)) {
      return res.status(403).json({ error: 'Invalid storage path' });
    }

    const alreadyRegistered = await prisma.document.findFirst({ where: { storagePath }, select: { id: true } });
    if (alreadyRegistered) return res.status(409).json({ error: 'This upload was already registered' });

    // Trust the stored object, not the client: it must exist and be within the size limit.
    const info = await getStorageFileInfo(storagePath);
    if (!info) return res.status(400).json({ error: 'Uploaded file not found. Please upload again.' });
    if (info.size > MAX_PDF_BYTES) {
      await deleteStorageFile(storagePath).catch(() => {});
      return res.status(413).json({ error: `PDF is too large (max ${MAX_PDF_BYTES / 1024 / 1024} MB)` });
    }

    const doc = await prisma.document.create({
      data: {
        userId,
        name: originalName,
        originalName,
        storagePath,
        mimeType: 'application/pdf',
        sizeBytes: info.size,
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
