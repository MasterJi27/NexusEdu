const { execSync } = require('child_process');

// 1. Node_modules are provisioned by the platform from node_modules.tar.gz
//    (committed artifact) — extraction happens before npm start. No npm
//    install here: npm ci took >600s at boot (slow registry) and the warmup
//    probe killed the container. tar.gz extraction is ~60s.
//    Note: the tar.gz is built on Windows, which stores .bin files as 0644
//    and dirs as 0755; chmod restores exec bits so `npx prisma` (which
//    resolves the local CLI) can run, and write access so generate can emit
//    its client into node_modules.
try {
  execSync('chmod -R a+rwx /node_modules', { stdio: 'ignore' });
} catch (e) {
  console.error('chmod failed:', e.message);
}

// 2. Run prisma generate so the client matches the bundled schema.
try {
  console.log('Running prisma generate...');
  execSync('npx prisma generate', { stdio: 'inherit', cwd: __dirname });
  console.log('prisma generate done');
} catch (e) {
  console.error('prisma generate failed:', e.message, (e.stderr || '').toString().slice(-600), (e.stdout || '').toString().slice(-600));
}

// 3. Apply schema changes via `migrate deploy` — replaces `db push
//    --accept-data-loss`, which would silently accept a lossy diff (a
//    dropped/narrowed column) on every restart with zero audit trail. The
//    live DB was schema-synced via db push with no migration history before
//    this change, so its very first run here hits P3005 ("schema already
//    exists, no _prisma_migrations table yet") — that's expected exactly
//    once: baseline the existing schema as already-applied, then retry.
//    Every deploy after that just applies new migrations normally.
try {
  console.log('Running prisma migrate deploy...');
  execSync('npx prisma migrate deploy', { stdio: 'inherit', cwd: __dirname });
  console.log('prisma migrate deploy done');
} catch (e) {
  const output = `${e.stderr || ''}${e.stdout || ''}`;
  if (output.includes('P3005')) {
    console.log('Pre-migration database detected — baselining 20260812120000_init...');
    try {
      execSync('npx prisma migrate resolve --applied "20260812120000_init"', { stdio: 'inherit', cwd: __dirname });
      execSync('npx prisma migrate deploy', { stdio: 'inherit', cwd: __dirname });
      console.log('Baseline resolved, prisma migrate deploy done');
    } catch (resolveError) {
      console.error('Baseline resolve failed:', resolveError.message, (resolveError.stderr || '').toString().slice(-600));
    }
  } else {
    console.error('prisma migrate deploy failed:', e.message, output.slice(-600));
  }
}

// 3. Start server
console.log('Starting server...');
require('./dist/index.js');
