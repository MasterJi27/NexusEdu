-- RAG: pgvector extension + knowledge chunk table
-- Run once against the database:
--   psql "$DATABASE_URL" -f prisma/manual_sql/rag.sql
CREATE EXTENSION IF NOT EXISTS vector;

-- Dimensions must match EMBEDDING_DIMENSIONS in src/services/ragService.ts.
-- OpenRouter nvidia/nemotron-3-embed-1b:free → 2048 (truncated to 2000 so the
-- HNSW index works on pgvector < 0.9.0, which caps HNSW at 2000 dims); Groq
-- nomic-embed-text-v1_5 → 768 (zero-padded up to 2000; padding does not affect
-- cosine similarity).
CREATE TABLE IF NOT EXISTS "KnowledgeChunk" (
    "id"         TEXT PRIMARY KEY,
    "userId"     TEXT,
    "sourceType" TEXT NOT NULL,
    "sourceId"   TEXT NOT NULL,
    "title"      TEXT NOT NULL,
    "content"    TEXT NOT NULL,
    "gradeLevel" TEXT,
    "subject"    TEXT,
    "embedding"  vector(2000),
    "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "KnowledgeChunk_userId_idx" ON "KnowledgeChunk" ("userId");
CREATE INDEX IF NOT EXISTS "KnowledgeChunk_sourceType_sourceId_idx" ON "KnowledgeChunk" ("sourceType", "sourceId");
CREATE INDEX IF NOT EXISTS "KnowledgeChunk_gradeLevel_subject_idx" ON "KnowledgeChunk" ("gradeLevel", "subject");
-- HNSW index is best-effort: pgvector < 0.9.0 caps HNSW at 2000 dimensions,
-- which is why the embedding column is vector(2000). The index is skipped when
-- unsupported (queries still work via seq scan; fine for small corpora).
DO $$
BEGIN
    BEGIN
        CREATE INDEX IF NOT EXISTS "KnowledgeChunk_embedding_idx"
            ON "KnowledgeChunk" USING hnsw ("embedding" vector_cosine_ops);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Skipping HNSW embedding index (unsupported dims): %', SQLERRM;
    END;
END $$;

-- Upgrade for pre-existing tables (v1 had no gradeLevel/subject columns).
ALTER TABLE "KnowledgeChunk" ADD COLUMN IF NOT EXISTS "gradeLevel" TEXT;
ALTER TABLE "KnowledgeChunk" ADD COLUMN IF NOT EXISTS "subject" TEXT;
-- Resize an older vector(2048) column (pre-2000-dim fix) so HNSW can be built.
ALTER TABLE "KnowledgeChunk" ALTER COLUMN "embedding" TYPE vector(2000);
