import { Response } from 'express';

/**
 * Verifies every required config value is present; if not, responds 503 and
 * returns null. Replaces the `if (!env.X) { res.status(503)... }` guard that
 * used to be copy-pasted at the top of every external-provider route.
 *
 * Returns the same config object back with values narrowed to `string` (not
 * `string | undefined`) — TS can't narrow `env.X` itself from a boolean
 * return value, so callers destructure the returned object instead of
 * re-reading `env.X` (which would still type as possibly-undefined).
 */
export function requireConfig<T extends Record<string, string | undefined>>(
  config: T,
  res: Response,
  label: string,
): { [K in keyof T]: string } | null {
  const missing = Object.entries(config)
    .filter(([, value]) => !value)
    .map(([key]) => key);
  if (missing.length > 0) {
    res.status(503).json({ error: `${label} is not configured (missing ${missing.join(', ')})` });
    return null;
  }
  return config as { [K in keyof T]: string };
}

/**
 * Calls an external JSON API and, on a non-2xx response, sends a formatted
 * 502 with a truncated error detail — the "fetch -> check !ok -> respond"
 * ceremony that used to be repeated at nearly every external-provider call
 * site in azureAi.ts. Returns the parsed body on success, or null after
 * already writing the error response on failure.
 */
export async function fetchJsonOrRespondError(
  url: string,
  options: RequestInit,
  res: Response,
  label: string,
): Promise<any | null> {
  try {
    const r = await fetch(url, options);
    const data = await r.json().catch(() => null);
    if (!r.ok) {
      const detail = (data as any)?.error?.message ?? JSON.stringify(data ?? {}).slice(0, 300);
      res.status(502).json({ error: `${label} failed (${r.status})`, detail });
      return null;
    }
    return data;
  } catch (error) {
    res.status(500).json({ error: `${label} failed`, detail: (error as Error).message });
    return null;
  }
}
