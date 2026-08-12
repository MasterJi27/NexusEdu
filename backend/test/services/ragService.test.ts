import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const queryRawUnsafe = vi.fn().mockResolvedValue([]);

vi.mock('../../src/lib/prisma', () => ({
  default: { $queryRawUnsafe: (...args: unknown[]) => queryRawUnsafe(...args) },
}));

import { retrieve } from '../../src/services/ragService';

/**
 * Regression coverage for a real bug: retrieve() used to always bind 5 SQL
 * parameters while the query text only referenced $4/$5 when gradeLevel or
 * subject were actually passed. Postgres requires the bound-parameter count
 * to exactly match the highest placeholder referenced in the parsed
 * statement, so every call with the default (no options) silently failed and
 * was swallowed by retrieve()'s own try/catch, returning []. The tutor had
 * been running fully ungrounded since RAG shipped.
 *
 * This inspects the actual SQL text and params array passed to the DB
 * driver, so a future edit that reintroduces a placeholder/param-count
 * mismatch fails here instead of silently degrading in production.
 */
describe('retrieve — SQL bind-parameter count', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    queryRawUnsafe.mockClear();
    // embedText's provider call — the vector's contents don't matter here,
    // only that retrieve() gets past it into the query-building logic.
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: [{ embedding: [0.1, 0.2, 0.3] }] }),
    }) as any;
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  function highestPlaceholder(sql: string): number {
    const matches = [...sql.matchAll(/\$(\d+)/g)].map((m) => Number(m[1]));
    return matches.length ? Math.max(...matches) : 0;
  }

  it('binds exactly 3 params when no gradeLevel/subject filter is given (the default, most common call)', async () => {
    await retrieve('user-1', 'photosynthesis');
    expect(queryRawUnsafe).toHaveBeenCalledOnce();
    const [sql, ...params] = queryRawUnsafe.mock.calls[0];
    expect(params).toHaveLength(3);
    expect(highestPlaceholder(sql)).toBe(3);
  });

  it('binds 4 params and references $4 when only gradeLevel is given', async () => {
    await retrieve('user-1', 'photosynthesis', 5, { gradeLevel: 'Class 10' });
    const [sql, ...params] = queryRawUnsafe.mock.calls[0];
    expect(params).toHaveLength(4);
    expect(highestPlaceholder(sql)).toBe(4);
    expect(sql).toContain('$4');
  });

  it('binds 4 params and references $4 when only subject is given', async () => {
    await retrieve('user-1', 'photosynthesis', 5, { subject: 'Biology' });
    const [sql, ...params] = queryRawUnsafe.mock.calls[0];
    expect(params).toHaveLength(4);
    expect(highestPlaceholder(sql)).toBe(4);
  });

  it('binds 5 params and references both $4 and $5 when both filters are given', async () => {
    await retrieve('user-1', 'photosynthesis', 5, { gradeLevel: 'Class 10', subject: 'Biology' });
    const [sql, ...params] = queryRawUnsafe.mock.calls[0];
    expect(params).toHaveLength(5);
    expect(sql).toContain('$4');
    expect(sql).toContain('$5');
  });

  it('never binds more or fewer parameters than the query text references, for every filter combination', async () => {
    const combos = [
      {},
      { gradeLevel: 'Class 10' },
      { subject: 'Biology' },
      { gradeLevel: 'Class 10', subject: 'Biology' },
    ];
    for (const options of combos) {
      queryRawUnsafe.mockClear();
      await retrieve('user-1', 'q', 5, options);
      const [sql, ...params] = queryRawUnsafe.mock.calls[0];
      expect(params.length).toBe(highestPlaceholder(sql));
    }
  });
});
