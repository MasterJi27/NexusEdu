import { describe, it, expect } from 'vitest';
import { resolveCorsOrigin } from '../../src/lib/cors';

describe('resolveCorsOrigin', () => {
  it('denies all cross-origin requests when nothing is configured', () => {
    // The exact regression this guards against: a missing/misconfigured
    // NODE_ENV on the host must never silently become allow-all-origins.
    expect(resolveCorsOrigin(undefined, false)).toBe(false);
  });

  it('denies all cross-origin requests for an empty ALLOWED_ORIGINS', () => {
    expect(resolveCorsOrigin('', false)).toBe(false);
    expect(resolveCorsOrigin('   ', false)).toBe(false);
  });

  it('returns the parsed origin list when ALLOWED_ORIGINS is set', () => {
    expect(resolveCorsOrigin('https://a.com,https://b.com', false)).toEqual([
      'https://a.com',
      'https://b.com',
    ]);
  });

  it('trims whitespace and drops empty entries from the origin list', () => {
    expect(resolveCorsOrigin(' https://a.com , , https://b.com ', false)).toEqual([
      'https://a.com',
      'https://b.com',
    ]);
  });

  it('only allows all origins when the explicit dev flag is true, and only as a fallback', () => {
    expect(resolveCorsOrigin(undefined, true)).toBe(true);
    // An explicit ALLOWED_ORIGINS always wins over the dev flag, whichever way it's set.
    expect(resolveCorsOrigin('https://a.com', true)).toEqual(['https://a.com']);
  });
});
