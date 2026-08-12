// backend/src/lib/env.ts throws at import time if these are unset — every
// test file transitively imports it (directly or via a route/service), so
// this has to run before any of those imports resolve.
process.env.JWT_SECRET ??= 'test-secret-do-not-use-in-production';
process.env.DATABASE_URL ??= 'postgresql://test:test@localhost:5432/test';
process.env.GROQ_API_KEY ??= 'test-groq-key';
process.env.OPENROUTER_API_KEY ??= 'test-openrouter-key';
process.env.EMBEDDING_PROVIDER ??= 'groq';
