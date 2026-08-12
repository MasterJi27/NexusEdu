// Prints the Gmail OAuth connect URL for the Composio workspace so the parent
// digest can be sent with GMAIL_SEND_EMAIL. Run: npm run composio:connect
require('dotenv').config({ path: __dirname + '/../.env' });
const { Composio } = require('@composio/core');

(async () => {
  const apiKey = process.env.COMPOSIO_API_KEY;
  if (!apiKey) {
    console.error('COMPOSIO_API_KEY missing from backend/.env');
    process.exit(1);
  }
  const client = new Composio({ apiKey });
  const ENTITY = 'default';

  const resp = await client.connectedAccounts.list({});
  const activeGmail = (resp?.items || []).filter(
    (x) => x.status === 'ACTIVE' && String(x.wordId || '').startsWith('gmail_'),
  );
  if (activeGmail.length > 0) {
    console.log(`Gmail already connected and ACTIVE (${activeGmail[0].id}). Send is ready.`);
    return;
  }

  const cfgs = await client.authConfigs.list({});
  const gmailCfg = (cfgs?.items || []).find((x) =>
    String(x.name || x.app || '').toLowerCase().includes('gmail'),
  );
  if (!gmailCfg) {
    console.error('No Gmail auth config in this Composio workspace.');
    console.error('Create one at console.composio.dev (Auth configs) then re-run.');
    process.exit(1);
  }

  const req = await client.connectedAccounts.link(ENTITY, gmailCfg.id);
  console.log('Open this URL and approve Google access (one time):\n');
  console.log(req.redirectUrl);
  console.log('\nAfter approving, re-run this script to confirm.');
})().catch((e) => {
  console.error('composio:connect failed:', e?.data?.message || e?.message || e?.error || e);
  process.exit(1);
});
