import prisma from '../lib/prisma';
import { env } from '../lib/env';

/**
 * RAG (retrieval-augmented generation) for the AI tutor.
 *
 * Study material (teacher notes) is split into chunks, embedded with a free
 * embedding model, and stored in a pgvector column. When a student chats with
 * the tutor, the query is embedded and the top-k similar chunks are injected
 * into the system prompt so answers are grounded in the student's actual
 * course material instead of generic model knowledge.
 *
 * Everything here is free-tier: the embedding call reuses the same provider
 * key the chat models use. No client-side keys, no extra accounts.
 */

export const EMBEDDING_DIMENSIONS = 2000;

/**
 * Hard ceiling on a single embedding call. Retrieval sits directly in front of
 * every /chat, /tutor/stream and /agent request, so an embeddings provider that
 * accepts the connection and then stalls would hang the whole reply — the
 * try/catch around retrieve() only catches rejections, never a hang. Aborting
 * turns that into a normal failure, which degrades to "no RAG context".
 */
const EMBEDDING_TIMEOUT_MS = 8000;

const EMBEDDING_ENDPOINTS: Record<string, { url: string; model: string }> = {
  groq: {
    url: 'https://api.groq.com/openai/v1/embeddings',
    model: 'nomic-embed-text-v1_5',
  },
  openrouter: {
    url: 'https://openrouter.ai/api/v1/embeddings',
    model: 'nvidia/nemotron-3-embed-1b:free',
  },
};

function embeddingConfig(): { url: string; model: string; apiKey?: string } {
  const provider = env.EMBEDDING_PROVIDER;
  const cfg = EMBEDDING_ENDPOINTS[provider] || EMBEDDING_ENDPOINTS.groq;
  const apiKey =
    provider === 'openrouter'
      ? env.OPENROUTER_API_KEY
      : env.GROQ_API_KEY;
  if (!apiKey) {
    throw new Error(`EMBEDDING_PROVIDER=${provider} needs its API key configured`);
  }
  return { url: cfg.url, model: env.EMBEDDING_MODEL || cfg.model, apiKey };
}

/** Embed one text into a normalized vector. */
export async function embedText(text: string): Promise<number[]> {
  const { url, model, apiKey } = embeddingConfig();
  let response: Response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ model, input: text }),
      signal: AbortSignal.timeout(EMBEDDING_TIMEOUT_MS),
    });
  } catch (error) {
    // AbortSignal.timeout rejects with a TimeoutError; name it explicitly so
    // the log distinguishes "provider is slow" from "provider is broken".
    if ((error as Error)?.name === 'TimeoutError') {
      throw new Error(`Embedding timed out after ${EMBEDDING_TIMEOUT_MS}ms`);
    }
    throw error;
  }
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Embedding error (${response.status}): ${body.slice(0, 300)}`);
  }
  const data = await response.json();
  const vector: number[] = data?.data?.[0]?.embedding;
  if (!Array.isArray(vector) || vector.length === 0) {
    throw new Error('Embedding response contained no vector');
  }
  return vector;
}

/**
 * Zero-pad a vector to EMBEDDING_DIMENSIONS. Providers return different
 * dimensionalities (Groq nomic: 768, OpenRouter nemotron: 1024); cosine
 * similarity is unaffected by zero padding, so all vectors can share one
 * pgvector column.
 */
function padVector(vector: number[]): number[] {
  if (vector.length === EMBEDDING_DIMENSIONS) return vector;
  if (vector.length > EMBEDDING_DIMENSIONS) return vector.slice(0, EMBEDDING_DIMENSIONS);
  return [...vector, ...new Array(EMBEDDING_DIMENSIONS - vector.length).fill(0)];
}

export function vectorLiteral(vector: number[]): string {
  return `[${padVector(vector).join(',')}]`;
}

/** Split long text into overlapping chunks (~450 words each). */
export function chunkText(text: string, maxWords = 450, overlap = 50): string[] {
  const normalized = text.replace(/\s+/g, ' ').trim();
  if (!normalized) return [];
  const sentences = normalized.split(/(?<=[.!?])\s+|\n+/);
  const chunks: string[] = [];
  let current: string[] = [];
  let words = 0;

  const flush = () => {
    if (current.length > 0) {
      const chunk = current.join(' ');
      chunks.push(chunk);
      const tail = chunk.split(' ').slice(-overlap);
      current = [...tail];
      words = tail.length;
    }
  };

  for (const sentence of sentences) {
    const sentenceWords = sentence.split(' ').length;
    if (words + sentenceWords > maxWords) {
      flush();
    }
    current.push(sentence);
    words += sentenceWords;
  }
  flush();
  return chunks;
}

export interface IndexInput {
  userId: string | null;
  sourceType: string;
  sourceId: string;
  title: string;
  content: string;
  gradeLevel?: string | null;
  subject?: string | null;
}

/** Replace all indexed chunks for a source with fresh ones. Never throws into
 *  the caller's request path — indexing is best-effort background work. */
export async function indexSource(input: IndexInput): Promise<number> {
  try {
    if (!env.RAG_ENABLED) return 0;
    await prisma.$executeRawUnsafe(
      `DELETE FROM "KnowledgeChunk" WHERE "sourceType" = $1 AND "sourceId" = $2`,
      input.sourceType,
      input.sourceId,
    );

    const chunks = chunkText(input.content);
    let indexed = 0;
    for (const chunk of chunks) {
      try {
        const vector = await embedText(chunk);
        await prisma.$executeRawUnsafe(
          `INSERT INTO "KnowledgeChunk"
             ("id", "userId", "sourceType", "sourceId", "title", "content",
              "gradeLevel", "subject", "embedding")
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::vector)`,
          crypto.randomUUID(),
          input.userId,
          input.sourceType,
          input.sourceId,
          input.title,
          chunk,
          input.gradeLevel ?? null,
          input.subject ?? null,
          vectorLiteral(vector),
        );
        indexed += 1;
      } catch (error) {
        console.error(`Failed to embed chunk of ${input.sourceType}:${input.sourceId}:`, error);
      }
    }
    return indexed;
  } catch (error) {
    console.error('Indexing failed:', error);
    return 0;
  }
}

/** Drop every chunk belonging to a source (used when the source is deleted). */
export async function deleteSourceIndex(sourceType: string, sourceId: string): Promise<void> {
  try {
    await prisma.$executeRawUnsafe(
      `DELETE FROM "KnowledgeChunk" WHERE "sourceType" = $1 AND "sourceId" = $2`,
      sourceType,
      sourceId,
    );
  } catch (error) {
    console.error('Index cleanup failed:', error);
  }
}

/**
 * Create the pgvector extension, KnowledgeChunk table and its indexes if they
 * aren't there yet. Mirrors prisma/manual_sql/rag.sql, which this repo has no
 * way to apply automatically: schema changes ship via `prisma migrate deploy`,
 * which — same as the `db push` it replaced — cannot create an extension or an
 * `Unsupported("vector")` column. Before
 * this ran at boot, a freshly provisioned database silently returned zero
 * chunks forever — RAG's own try/catch swallowed the "relation does not exist"
 * error, so the tutor just quietly stopped being grounded.
 *
 * Every statement is idempotent, so running it on each start is a no-op after
 * the first. Failures are logged and swallowed: a database whose user lacks
 * CREATE EXTENSION rights should still boot and serve everything else.
 */
export async function ensureRagSchema(): Promise<void> {
  if (!env.RAG_ENABLED) return;
  const statements = [
    `CREATE EXTENSION IF NOT EXISTS vector`,
    `CREATE TABLE IF NOT EXISTS "KnowledgeChunk" (
       "id"         TEXT PRIMARY KEY,
       "userId"     TEXT,
       "sourceType" TEXT NOT NULL,
       "sourceId"   TEXT NOT NULL,
       "title"      TEXT NOT NULL,
       "content"    TEXT NOT NULL,
       "gradeLevel" TEXT,
       "subject"    TEXT,
       "embedding"  vector(${EMBEDDING_DIMENSIONS}),
       "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
     )`,
    `ALTER TABLE "KnowledgeChunk" ADD COLUMN IF NOT EXISTS "gradeLevel" TEXT`,
    `ALTER TABLE "KnowledgeChunk" ADD COLUMN IF NOT EXISTS "subject" TEXT`,
    // Resize an older vector(2048) column down to the current dimension so the
    // HNSW index (2000-dim cap on pgvector < 0.9.0) can be created. No-op when
    // the column is already the right size or the table is freshly created.
    `ALTER TABLE "KnowledgeChunk" ALTER COLUMN "embedding" TYPE vector(${EMBEDDING_DIMENSIONS})`,
    `CREATE INDEX IF NOT EXISTS "KnowledgeChunk_userId_idx" ON "KnowledgeChunk" ("userId")`,
    `CREATE INDEX IF NOT EXISTS "KnowledgeChunk_sourceType_sourceId_idx" ON "KnowledgeChunk" ("sourceType", "sourceId")`,
    `CREATE INDEX IF NOT EXISTS "KnowledgeChunk_gradeLevel_subject_idx" ON "KnowledgeChunk" ("gradeLevel", "subject")`,
  ];
  for (const statement of statements) {
    try {
      await prisma.$executeRawUnsafe(statement);
    } catch (error) {
      console.error(
        'RAG schema setup failed (retrieval will return nothing until this is fixed):',
        (error as Error)?.message ?? error,
      );
      return;
    }
  }
  // The HNSW index is best-effort: pgvector < 0.9.0 caps HNSW at 2000
  // dimensions and the embedding vector is EMBEDDING_DIMENSIONS, so a fresh
  // database would fail boot entirely if this were not tolerated. Queries
  // still work via seq scan (fine for small corpora).
  try {
    await prisma.$executeRawUnsafe(
      `CREATE INDEX IF NOT EXISTS "KnowledgeChunk_embedding_idx" ON "KnowledgeChunk" USING hnsw ("embedding" vector_cosine_ops)`,
    );
  } catch (error) {
    console.warn(
      'Skipped HNSW embedding index (unsupported dimensions for this pgvector build):',
      (error as Error)?.message ?? error,
    );
  }
}

export interface RetrievedChunk {
  title: string;
  sourceType: string;
  content: string;
  score: number;
}

export interface RetrieveOptions {
  k?: number;
  gradeLevel?: string | null;
  subject?: string | null;
}

/**
 * Top-k semantic search over the caller's chunks plus shared ones. Returns []
 * when RAG is disabled or the query could not be embedded. Optional
 * gradeLevel/subject filters narrow the corpus.
 */
export async function retrieve(
  userId: string | null,
  query: string,
  k = 5,
  options: RetrieveOptions = {},
): Promise<RetrievedChunk[]> {
  try {
    if (!env.RAG_ENABLED) return [];
    const vector = await embedText(query);
    const limit = options.k ?? k;

    // Placeholders are numbered by how many params are actually bound, not by
    // a fixed $4/$5 — Postgres's bind protocol requires the parameter count
    // to exactly match the placeholders referenced in the parsed statement,
    // so a query text that omits $4/$5 while 5 values are still passed fails
    // on every call with a bind-count mismatch.
    const params: unknown[] = [vectorLiteral(vector), userId ?? '', limit];
    let gradeClause = '';
    if (options.gradeLevel) {
      params.push(options.gradeLevel);
      gradeClause = `AND "gradeLevel" = $${params.length}`;
    }
    let subjectClause = '';
    if (options.subject) {
      params.push(options.subject);
      subjectClause = `AND "subject" = $${params.length}`;
    }

    const rows: { title: string; sourceType: string; content: string; distance: number }[] =
      await prisma.$queryRawUnsafe(
        `SELECT "title", "sourceType", "content", "embedding" <=> $1::vector AS distance
         FROM "KnowledgeChunk"
         WHERE ("userId" = $2 OR "userId" IS NULL)
           AND "embedding" IS NOT NULL
           ${gradeClause}
           ${subjectClause}
         ORDER BY "embedding" <=> $1::vector
         LIMIT $3`,
        ...params,
      );
    return rows.map((row) => ({
      title: row.title,
      sourceType: row.sourceType,
      content: row.content,
      score: Math.max(0, 1 - row.distance),
    }));
  } catch (error) {
    console.error('RAG retrieval failed:', error);
    return [];
  }
}

/** Format retrieved chunks into a compact context block for the system prompt. */
export function buildRagContext(chunks: RetrievedChunk[]): string {
  if (chunks.length === 0) return '';
  const sections = chunks
    .map((chunk, index) => `[${index + 1}] ${chunk.title}\n${chunk.content}`)
    .join('\n\n');
  return (
    'Relevant study material from the student\'s course:\n\n' +
    sections +
    '\n\nWhen answering, ground your response in this material. ' +
    'If it does not answer the question, say so honestly and use your general knowledge.'
  );
}
