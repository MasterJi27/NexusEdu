import { env } from '../lib/env';

// Optional email delivery through Composio (agent platform): the parent digest
// is sent with GMAIL_SEND_EMAIL using a Gmail account connected to the
// Composio workspace (run `npm run composio:connect` to link one). When
// COMPOSIO_API_KEY is unset or no Gmail is connected, callers fall back to
// SMTP, then to in-app-only. Never throws unexpected errors — send failures
// return false.

// @composio/core is ESM-only; this package is CommonJS, so import it lazily.
// Structural interface instead of a type import (CJS→ESM type imports need a
// resolution-mode attribute we don't want to depend on).
interface ComposioLike {
  authConfigs: {
    list(opts: object): Promise<{
      items?: Array<{ id?: string; name?: string; toolkit?: { slug?: string } }>;
    }>;
  };
  connectedAccounts: {
    list(opts: object): Promise<{ items?: unknown[] }>;
    link(
      userId: string,
      authConfigId: string,
    ): Promise<{ redirectUrl?: string } | undefined>;
  };
  tools: {
    execute(
      slug: string,
      params: {
        userId: string;
        arguments: Record<string, unknown>;
        dangerouslySkipVersionCheck: boolean;
      },
    ): Promise<{ error?: unknown }>;
  };
}

const ENTITY = 'default';

let client: ComposioLike | null = null;
let gmailAuthConfigId: string | null = null;
let authConfigChecked = false;
let connectionOk = false;
let connectionCheckedAt = 0;
const CONNECTION_CACHE_MS = 60 * 1000;

async function getClient(): Promise<ComposioLike | null> {
  if (!env.COMPOSIO_API_KEY) return null;
  if (client) return client;
  try {
    const mod = await import('@composio/core');
    client = new mod.Composio({ apiKey: env.COMPOSIO_API_KEY }) as unknown as ComposioLike;
  } catch (error) {
    console.error('Composio client init failed:', error);
    client = null;
  }
  return client;
}

async function getGmailAuthConfigId(c: ComposioLike): Promise<string | null> {
  if (authConfigChecked) return gmailAuthConfigId;
  authConfigChecked = true;
  try {
    const resp = await c.authConfigs.list({});
    const cfg = (resp?.items || []).find((x) =>
      (x.name || x.toolkit?.slug || '').toLowerCase().includes('gmail'),
    );
    gmailAuthConfigId = cfg?.id || null;
  } catch (error) {
    console.error('Composio auth config lookup failed:', error);
  }
  return gmailAuthConfigId;
}

/** Cached check: is an ACTIVE Gmail account connected to this workspace? */
export async function isGmailConnected(): Promise<boolean> {
  const c = await getClient();
  if (!c) return false;
  const now = Date.now();
  if (now - connectionCheckedAt < CONNECTION_CACHE_MS) return connectionOk;
  connectionCheckedAt = now;
  try {
    const resp = await c.connectedAccounts.list({});
    const items = (resp?.items || []) as unknown as {
      status?: string;
      wordId?: string | null;
      authConfigId?: string | null;
    }[];
    const gmailCfg = await getGmailAuthConfigId(c);
    connectionOk = items.some(
      (acc) =>
        acc.status === 'ACTIVE' &&
        ((acc.wordId || '').startsWith('gmail_') ||
          (gmailCfg && acc.authConfigId === gmailCfg)),
    );
  } catch (error) {
    console.error('Composio connection check failed:', error);
    connectionOk = false;
  }
  return connectionOk;
}

/**
 * OAuth connect URL for the app owner's Gmail (uses the existing Gmail auth
 * config in the workspace). Returns the URL; after the user completes the
 * Google consent screen, isGmailConnected() flips to true.
 */
export async function getGmailConnectUrl(): Promise<{
  url: string;
  alreadyConnected: boolean;
}> {
  const c = await getClient();
  if (!c) throw new Error('COMPOSIO_API_KEY is not set');
  if (await isGmailConnected()) return { url: '', alreadyConnected: true };
  const authConfigId = await getGmailAuthConfigId(c);
  if (!authConfigId) {
    throw new Error(
      'No Gmail auth config in this Composio workspace. Create one at console.composio.dev (Auth configs) then re-run.',
    );
  }
  const request = await c.connectedAccounts.link(ENTITY, authConfigId);
  const url = request?.redirectUrl || '';
  if (!url) throw new Error('Composio returned no connection URL');
  return { url, alreadyConnected: false };
}

/**
 * Send an email through the connected Gmail. Resolves when delivered.
 * Throws Error with a message the caller can log or surface.
 */
export async function sendViaComposio(opts: {
  to: string;
  subject: string;
  body: string;
}): Promise<void> {
  const c = await getClient();
  if (!c) throw new Error('COMPOSIO_API_KEY is not set');
  const result = await c.tools.execute('GMAIL_SEND_EMAIL', {
    userId: ENTITY,
    arguments: {
      recipient_email: opts.to,
      subject: opts.subject,
      body: opts.body,
    },
    dangerouslySkipVersionCheck: true,
  });
  if (result?.error) throw new Error(String(result.error));
}
