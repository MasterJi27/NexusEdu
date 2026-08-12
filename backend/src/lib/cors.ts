/**
 * Fails closed, not open: with no allowedOriginsRaw configured, this denies
 * all cross-origin requests by default — it does NOT infer permissiveness
 * from NODE_ENV, since a missing/misconfigured NODE_ENV on the host would
 * otherwise silently turn into allow-all-origins in production. The only way
 * to get the permissive local-dev behaviour is the explicit opt-in flag,
 * which a developer sets deliberately in their own .env and would never end
 * up in a hosting platform's settings by accident.
 */
export function resolveCorsOrigin(
  allowedOriginsRaw: string | undefined,
  allowAllDev: boolean,
): string[] | boolean {
  const allowedOrigins = allowedOriginsRaw?.split(',').map((o) => o.trim()).filter(Boolean);
  if (allowedOrigins && allowedOrigins.length > 0) return allowedOrigins;
  return allowAllDev;
}
