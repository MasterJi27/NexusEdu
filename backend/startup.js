const { execSync, spawn } = require('child_process');
const path = require('path');

// Helper to redact secrets from logs — replaces password in DATABASE_URL
function redact(str) {
  if (!str || typeof str !== 'string') return str;
  return str
    .replace(/(postgres(?:ql)?:\/\/[^:]+:)[^@]+@/gi, '$1***@')
    .replace(/(DATABASE_URL\s*=\s*postgres(?:ql)?:\/\/[^:]+:)[^@\s]+@/gi, '$1***@');
}

// Override console.log/error to redact DATABASE_URL automatically
const _origLog = console.log;
const _origError = console.error;
console.log = (...args) => _origLog(...args.map(a => typeof a === 'string' ? redact(a) : a));
console.error = (...args) => _origError(...args.map(a => typeof a === 'string' ? redact(a) : a));

// Respect DATABASE_URL from env but never log its raw value
if (process.env.DATABASE_URL) {
  console.log('DATABASE_URL configured: ***redacted***');
}

// 1. Restore executable bits securely — use 755 least-privilege (no world-writable)
//    Node_modules tar extraction on App Service loses mode bits; restore minimal needed.
//    Use 755 for dirs, 644 for files (least-privilege); only .bin needs exec.
try {
  // Try both possible layouts: ZipDeploy extracts to /node_modules, Docker to ./node_modules
  const targets = ['/node_modules', path.join(__dirname, 'node_modules')];
  for (const t of targets) {
    try {
      execSync(`find "${t}" -type d -exec chmod 755 {} \\;`, { stdio: 'ignore' });
    } catch {}
    try {
      execSync(`find "${t}" -type f -exec chmod 644 {} \\;`, { stdio: 'ignore' });
    } catch {}
  }
  // Restore exec bit only on .bin scripts if present (least-privilege: only .bin needs 755)
  try { execSync('find /app/node_modules/.bin -type f -exec chmod 755 {} \\; 2>/dev/null || true', { stdio: 'ignore' }); } catch {}
} catch (e) {
  console.error('chmod 755 restore failed:', redact(e.message));
}

// 2. Prisma client generation REMOVED on boot — client is already baked into dist/src/generated
//    at build time (Dockerfile build step + deploy_azure.py pre-build). Running that step
//    on every boot races across 3-30 instances, slows cold start, and can corrupt
//    node_modules under concurrent writes without distributed lock. Drift is detected by migrate deploy.
//    Intentionally no generate step here.

// 3. Apply schema changes via `migrate deploy` guarded by pg_advisory_lock so only one of 3-30
//    instances actually runs DDL. Others skip quickly. pg_advisory_lock is Postgres-distributed
//    (unlike local filesystem locks which cannot coordinate across 30 containers/instances).
//    Preserves P3005 baseline logic.
async function runMigrateDeploy() {
  const ADVISORY_LOCK_KEY = 727482; // fixed 32-bit key for nexus-edu migrations (pg_advisory_lock)
  let client = null;
  let hasLock = false;
  try {
    console.log('Running prisma migrate deploy (pg_advisory_lock-guarded)...');
    // Try to acquire Postgres advisory lock if DATABASE_URL is available.
    // pg_try_advisory_lock is non-blocking; if another instance holds it we skip.
    if (process.env.DATABASE_URL) {
      try {
        const { Client } = require('pg');
        client = new Client({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 5000 });
        await client.connect();
        const res = await client.query('SELECT pg_try_advisory_lock($1) AS locked', [ADVISORY_LOCK_KEY]);
        hasLock = res.rows[0]?.locked === true;
        if (!hasLock) {
          console.log('Migrate locked by another instance (pg_advisory_lock) — skipping, will be ready shortly');
          await client.end().catch(() => {});
          client = null;
          return;
        }
        console.log('Acquired pg_advisory_lock for migrations');
      } catch (lockErr) {
        console.error('pg_advisory_lock acquire failed, proceeding without distributed lock:', redact(lockErr.message));
        hasLock = false;
        if (client) { try { await client.end(); } catch {} client = null; }
        // Fall through to run migrate without lock — better than skipping entirely
      }
    } else {
      console.log('DATABASE_URL not set — running migrate without advisory lock');
    }

    const runDeploy = () => {
      const out = execSync('npx prisma migrate deploy', { cwd: __dirname, stdio: ['ignore', 'pipe', 'pipe'], timeout: 120000 });
      if (out?.length) console.log(out.toString());
      console.log(`prisma migrate deploy done${hasLock ? ' (via pg_advisory_lock)' : ''}`);
    };

    try {
      runDeploy();
      return;
    } catch (e) {
      const output = `${e.stderr || ''}${e.stdout || ''}`;
      const redactedOut = redact(output);
      if (output.includes('P3005')) {
        console.log('Pre-migration database detected — baselining 20260812120000_init...');
        try {
          execSync('npx prisma migrate resolve --applied "20260812120000_init"', { cwd: __dirname, stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 });
          const out2 = execSync('npx prisma migrate deploy', { cwd: __dirname, stdio: ['ignore', 'pipe', 'pipe'], timeout: 120000 });
          if (out2?.length) console.log(out2.toString());
          console.log('Baseline resolved, prisma migrate deploy done');
          return;
        } catch (resolveError) {
          console.error('Baseline resolve failed:', redact(resolveError.message), redact(`${resolveError.stderr || ''}${resolveError.stdout || ''}`.slice(-600)));
        }
      } else {
        console.error('prisma migrate deploy failed:', redact(e.message), redactedOut.slice(-600));
      }
    }
  } finally {
    // Release advisory lock and disconnect if we acquired it
    if (client && hasLock) {
      try {
        await client.query('SELECT pg_advisory_unlock($1)', [ADVISORY_LOCK_KEY]);
        console.log('Released pg_advisory_lock');
      } catch {}
      try { await client.end(); } catch {}
    } else if (client) {
      try { await client.end(); } catch {}
    }
  }
}

// 4. Start server with graceful SIGTERM drain
// Track server handle if dist/index.js exports it; otherwise rely on its own handler.
// We wrap require so we can intercept SIGTERM before Node exits.
let serverHandle = null;
let shuttingDown = false;

// Intercept SIGTERM/SIGINT for drain — give in-flight requests 25s to finish, then close DB
function setupDrain() {
  const drain = async (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`Received ${signal}, draining connections...`);
    // Stop accepting new connections
    try {
      if (serverHandle && typeof serverHandle.close === 'function') {
        await new Promise((resolve) => {
          const timeout = setTimeout(() => {
            console.log('Drain timeout — forcing exit');
            resolve();
          }, 25000);
          serverHandle.close(() => {
            clearTimeout(timeout);
            console.log('HTTP server closed — draining complete');
            resolve();
          });
        });
      } else {
        // Fallback: give index.ts handler 10s to drain before we force
        await new Promise(r => setTimeout(r, 5000));
      }
    } catch (err) {
      console.error('Drain error:', redact(err && err.message ? err.message : String(err)));
    }
    // Disconnect Prisma if available
    try {
      const prismaModule = require('./dist/lib/prisma.js');
      const prisma = prismaModule.prisma || prismaModule.default;
      if (prisma && typeof prisma.$disconnect === 'function') {
        await prisma.$disconnect();
        console.log('Prisma disconnected');
      }
    } catch {}
    // Also attempt redis disconnect
    try {
      const redisMod = require('./dist/lib/redis.js');
      if (redisMod && typeof redisMod.disconnectRedis === 'function') await redisMod.disconnectRedis();
    } catch {}
    process.exit(0);
  };
  process.on('SIGTERM', () => drain('SIGTERM'));
  process.on('SIGINT', () => drain('SIGINT'));
  // Kubernetes/App Service may send SIGTERM then SIGKILL after 30s — handle gracefully
  process.on('uncaughtException', (err) => {
    console.error('Uncaught exception:', redact(err && err.stack ? err.stack : String(err)));
  });
}

async function startServer() {
  console.log('Starting server...');
  setupDrain();

  // Require the compiled server — index.ts does app.listen and registers its own SIGTERM handler too
  // Capture returned server if exported
  try {
    const mod = require('./dist/index.js');
    // index.ts `app.listen` returns http.Server; if exported, capture it
    if (mod && mod.server && typeof mod.server.close === 'function') serverHandle = mod.server;
    // Also check default export
    if (!serverHandle && mod && mod.default && typeof mod.default.close === 'function') serverHandle = mod.default;
    // If index.js attaches to global, check
    if (!serverHandle && global.__nexusServer && typeof global.__nexusServer.close === 'function') serverHandle = global.__nexusServer;
  } catch (e) {
    console.error('Failed to start server:', redact(e && e.stack ? e.stack : String(e)));
    process.exit(1);
  }
}

// Main: run migrations under pg_advisory_lock, then start server
(async () => {
  await runMigrateDeploy();
  await startServer();
})();
