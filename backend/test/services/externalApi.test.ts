import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Response } from 'express';
import { requireConfig, fetchJsonOrRespondError } from '../../src/services/externalApi';

function mockResponse(): Response {
  const res: any = {};
  res.status = vi.fn().mockReturnValue(res);
  res.json = vi.fn().mockReturnValue(res);
  return res as Response;
}

describe('requireConfig', () => {
  it('returns the config object when every value is present', () => {
    const res = mockResponse();
    const result = requireConfig({ KEY_A: 'a', KEY_B: 'b' }, res, 'Test service');
    expect(result).toEqual({ KEY_A: 'a', KEY_B: 'b' });
    expect(res.status).not.toHaveBeenCalled();
  });

  it('responds 503 and returns null when a value is missing', () => {
    const res = mockResponse();
    const result = requireConfig({ KEY_A: 'a', KEY_B: undefined }, res, 'Test service');
    expect(result).toBeNull();
    expect(res.status).toHaveBeenCalledWith(503);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: expect.stringContaining('KEY_B') }),
    );
  });

  it('lists every missing key, not just the first', () => {
    const res = mockResponse();
    requireConfig({ KEY_A: undefined, KEY_B: undefined }, res, 'Test service');
    const message = (res.json as any).mock.calls[0][0].error as string;
    expect(message).toContain('KEY_A');
    expect(message).toContain('KEY_B');
  });
});

describe('fetchJsonOrRespondError', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('returns the parsed body on a 2xx response', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ hello: 'world' }),
    }) as any;
    const res = mockResponse();
    const result = await fetchJsonOrRespondError('https://example.com', {}, res, 'Test');
    expect(result).toEqual({ hello: 'world' });
    expect(res.status).not.toHaveBeenCalled();
  });

  it('responds 502 with a truncated detail on a non-2xx response', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 429,
      json: async () => ({ error: { message: 'rate limited' } }),
    }) as any;
    const res = mockResponse();
    const result = await fetchJsonOrRespondError('https://example.com', {}, res, 'Test');
    expect(result).toBeNull();
    expect(res.status).toHaveBeenCalledWith(502);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Test failed (429)', detail: 'rate limited' }),
    );
  });

  it('responds 500 when the fetch itself throws (network failure)', async () => {
    global.fetch = vi.fn().mockRejectedValue(new Error('ECONNRESET')) as any;
    const res = mockResponse();
    const result = await fetchJsonOrRespondError('https://example.com', {}, res, 'Test');
    expect(result).toBeNull();
    expect(res.status).toHaveBeenCalledWith(500);
  });
});
