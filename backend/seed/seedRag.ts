/**
 * Seeds the shared RAG corpus with NCERT-aligned study material.
 *
 * Every item becomes a set of KnowledgeChunk rows owned by no one
 * (userId = null), so every student's tutor retrieves them.
 *
 * Usage: npm run seed:rag
 */
import '../src/lib/loadEnv';
import { indexSource } from '../src/services/ragService';
import { RAG_SEED } from './ragContent';

async function main() {
  console.log(`Seeding ${RAG_SEED.length} study documents...`);
  let totalChunks = 0;
  let failures = 0;

  for (const item of RAG_SEED) {
    const key = `${item.gradeLevel} - ${item.subject} - ${item.title}`;
    try {
      const chunks = await indexSource({
        userId: null,
        sourceType: 'seed_content',
        sourceId: item.title,
        title: item.title,
        content: item.content,
        gradeLevel: item.gradeLevel,
        subject: item.subject,
      });
      if (chunks === 0) {
        throw new Error('indexed 0 chunks');
      }
      totalChunks += chunks;
      console.log(`  OK  ${key} (${chunks} chunks)`);
    } catch (error) {
      failures += 1;
      console.error(`  FAIL ${key}:`, error);
    }
  }

  console.log(
    `\nDone. ${totalChunks} chunks indexed across ${RAG_SEED.length - failures} documents, ${failures} failures.`,
  );
  if (failures > 0) process.exitCode = 1;
}

main();
