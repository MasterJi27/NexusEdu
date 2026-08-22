import { Router } from 'express';
import multer from 'multer';
import crypto from 'crypto';
import pdfParse from 'pdf-parse';
import { authenticate, AuthRequest } from '../middlewares/auth';
import prisma from '../lib/prisma';
import { indexSource } from '../services/ragService';
import { consumeAiRequest } from '../services/aiService';

const router = Router();

/**
 * Document uploads for the AI chat. Files are held in memory (they are
 * parsed immediately, never persisted as blobs): PDFs get their text
 * extracted and indexed into RAG so the tutor can answer from them; ChatGPT
 * exports are sanitized and stored as conversations for the client.
 */

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/pdf') cb(null, true);
    else cb(new Error('Only PDF files are allowed here.'));
  },
});

const importUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
});

// Same continuous-refill AI request bucket as /api/ai so doc uploads and
// imports cannot be abused to burn embedding/import work without bounds.
router.use(authenticate, async (req: AuthRequest, res, next) => {
  try {
    const result = await consumeAiRequest(req.user!.id);
    if (!result.allowed) {
      res.status(429).json({ error: 'Too many AI requests. Try again in a moment.' });
      return;
    }
    next();
  } catch (error) {
    console.error('AI request bucket check failed:', error);
    next();
  }
});

const MAX_PDF_CHARS = 200_000;

/** Extract text from a PDF buffer. pdf-parse needs a Buffer, not a view. */
async function extractPdfText(buffer: Buffer): Promise<{ text: string; pages: number }> {
  const data = await pdfParse(buffer);
  return { text: (data.text || '').slice(0, MAX_PDF_CHARS), pages: data.numpages || 0 };
}

/**
 * POST /api/ai/upload-doc (multipart, field "file", .pdf only)
 * Extracts the PDF text, indexes it into the user's RAG store and returns a
 * summary so the client can confirm. Any question asked afterwards is
 * grounded in the document.
 */
router.post('/upload-doc', upload.single('file'), async (req: AuthRequest, res): Promise<void> => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'Attach a PDF file to upload.' });
      return;
    }
    const title = (req.file.originalname || 'document.pdf').replace(/\.pdf$/i, '');
    const { text, pages } = await extractPdfText(req.file.buffer);
    if (!text.trim()) {
      res.status(422).json({ error: 'Could not read any text from this PDF (it may be a scanned image).' });
      return;
    }

    const sourceId = crypto.randomUUID();
    let chunks = 0;
    try {
      chunks = await indexSource({
        userId: req.user!.id,
        sourceType: 'uploaded_pdf',
        sourceId,
        title,
        content: text,
      });
    } catch (error) {
      // Indexing is best-effort; the upload itself still succeeds.
      console.error('PDF RAG indexing failed:', error);
    }

    res.json({ title, pages, charCount: text.length, chunks });
  } catch (error: any) {
    const message = error?.message?.includes('PDF') ? error.message : 'Could not read this PDF. Try a smaller file.';
    res.status(400).json({ error: message });
  }
});

const MAX_CONVERSATIONS = 100;
const MAX_MESSAGES_PER_CHAT = 300;
const MAX_MESSAGE_CHARS = 4000;

/** Flatten one ChatGPT message part into plain text. */
function flattenPart(part: any): string {
  if (typeof part === 'string') return part;
  if (part && typeof part === 'object') {
    if (typeof part.text === 'string') return part.text;
    if (typeof part.content === 'string') return part.content;
    if (Array.isArray(part.parts)) return flattenParts(part.parts);
  }
  return '';
}

function flattenParts(parts: any): string {
  if (typeof parts === 'string') return parts;
  if (Array.isArray(parts)) {
    return parts
      .map(flattenPart)
      .filter(Boolean)
      .join('\n')
      .slice(0, MAX_MESSAGE_CHARS);
  }
  return '';
}

/**
 * Tolerant parser for ChatGPT exports. Accepts both the raw
 * conversations.json array ({id, title, mapping}) and a pre-sanitized
 * [{id, title, messages: [{role, content}]}] shape from the client.
 */
function parseChatGptExport(payload: any): { id: string; title: string; messages: { role: string; content: string }[] }[] {
  if (!Array.isArray(payload)) return [];
  const out: { id: string; title: string; messages: { role: string; content: string }[] }[] = [];
  for (const convo of payload.slice(0, MAX_CONVERSATIONS)) {
    if (!convo || typeof convo !== 'object') continue;
    const messages: { role: string; content: string }[] = [];

    if (Array.isArray(convo.messages)) {
      // Pre-sanitized shape.
      for (const m of convo.messages.slice(0, MAX_MESSAGES_PER_CHAT)) {
        const role = m?.role === 'assistant' || m?.role === 'user' ? m.role : undefined;
        const content = flattenParts(m?.content);
        if (role && content) messages.push({ role, content });
      }
    } else if (convo.mapping && typeof convo.mapping === 'object') {
      // Raw ChatGPT export: walk the mapping tree, keep user/assistant turns.
      const nodes: any[] = Object.values(convo.mapping).filter(
        (n: any) => n?.message?.author?.role === 'user' || n?.message?.author?.role === 'assistant',
      );
      nodes.sort((a: any, b: any) => (a.message.create_time ?? 0) - (b.message.create_time ?? 0));
      for (const node of nodes.slice(0, MAX_MESSAGES_PER_CHAT)) {
        const role = node.message.author.role as 'user' | 'assistant';
        const content = flattenParts(node.message.content?.parts);
        if (content) messages.push({ role, content });
      }
    }

    if (messages.length === 0) continue;
    out.push({
      id: typeof convo.id === 'string' ? convo.id.slice(0, 64) : crypto.randomUUID(),
      title:
        typeof convo.title === 'string' && convo.title.trim()
          ? convo.title.trim().slice(0, 200)
          : `ChatGPT chat ${out.length + 1}`,
      messages,
    });
  }
  return out;
}

/**
 * POST /api/ai/import-chatgpt (multipart, field "file": conversations.json
 * or a zip containing it). Stores the sanitized conversations so the client
 * can browse them and continue them in the tutor chat.
 */
router.post('/import-chatgpt', importUpload.single('file'), async (req: AuthRequest, res): Promise<void> => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'Attach your ChatGPT conversations.json export.' });
      return;
    }
    let payload: any;
    try {
      payload = JSON.parse(req.file.buffer.toString('utf8'));
    } catch {
      res.status(400).json({ error: 'That file is not valid JSON. Use the conversations.json from your ChatGPT export.' });
      return;
    }

    const conversations = parseChatGptExport(payload);
    if (conversations.length === 0) {
      res.status(422).json({ error: 'No usable conversations found in this file.' });
      return;
    }

    const data = conversations.map((c) => ({
      userId: req.user!.id,
      source: 'chatgpt',
      title: c.title,
      messages: c.messages as unknown as object,
    }));
    await prisma.importedChat.createMany({ data });

    res.json({
      imported: data.length,
      conversations: data.map((d) => ({
        title: d.title,
        messageCount: (d.messages as { role: string; content: string }[]).length,
      })),
    });
  } catch (error: any) {
    console.error('ChatGPT import failed:', error);
    res.status(500).json({ error: 'Import failed. Please try again.' });
  }
});

/** GET /api/ai/imported-chats — the user's imported conversations. */
router.get('/imported-chats', async (req: AuthRequest, res): Promise<void> => {
  try {
    const rows = await prisma.importedChat.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: 'desc' },
      select: { id: true, title: true, createdAt: true, messages: true },
      take: 100,
    });
    res.json(
      rows.map((r) => ({
        id: r.id,
        title: r.title,
        createdAt: r.createdAt,
        messageCount: (r.messages as { role: string; content: string }[]).length,
        preview: (r.messages as { role: string; content: string }[])[0]?.content.slice(0, 120) ?? '',
      })),
    );
  } catch (error) {
    console.error('List imported chats failed:', error);
    res.status(500).json({ error: 'Failed to load imported chats.' });
  }
});

/** GET /api/ai/imported-chats/:id — full conversation for the viewer. */
router.get('/imported-chats/:id', async (req: AuthRequest, res): Promise<void> => {
  try {
    const row = await prisma.importedChat.findFirst({
      where: { id: String(req.params.id), userId: req.user!.id },
    });
    if (!row) {
      res.status(404).json({ error: 'Conversation not found.' });
      return;
    }
    res.json({ id: row.id, title: row.title, messages: row.messages });
  } catch (error) {
    console.error('Get imported chat failed:', error);
    res.status(500).json({ error: 'Failed to load conversation.' });
  }
});

export default router;