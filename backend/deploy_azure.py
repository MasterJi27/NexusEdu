import os
import shutil
import zipfile
import subprocess
import sys
import time
import argparse
import fnmatch
from pathlib import Path

# Patterns to exclude from zip — secrets and local artifacts must never be deployed
EXCLUDE_PATTERNS = [
    '.env',
    '.env.*',
    '*.jks',
    '*.keystore',
    '*.pem',
    '*.p12',
    '*.pfx',
    '.git/*',
    '.gitignore',
    '*.log',
    'deploy.zip',
    'deploy*.zip',
    '.vscode/*',
    '.idea/*',
    'coverage/*',
]

# Also never include these files even if matched as include_files (defense in depth)
EXCLUDE_FILES_EXACT = {'.env', '.gitignore'}

def should_exclude(archive_name: str) -> bool:
    # archive_name is posix path like 'dist/index.js' or '.env'
    base = os.path.basename(archive_name)
    for pat in EXCLUDE_PATTERNS:
        # fnmatch for basename and full path
        if fnmatch.fnmatch(archive_name, pat) or fnmatch.fnmatch(base, pat):
            return True
        # handle .env.* specially
        if pat == '.env.*' and base.startswith('.env.'):
            return True
    if archive_name in EXCLUDE_FILES_EXACT or base in EXCLUDE_FILES_EXACT:
        return True
    return False

def build():
    # dist/ is gitignored and never rebuilt by this script on its own — a
    # stale dist/ (e.g. containing a route file already deleted from src/)
    # would get zipped and deployed as-is. tsc also never deletes output for
    # source files that were removed, so dist/ is wiped first, not just
    # overwritten.
    print("Cleaning previous build output...")
    if os.path.exists('dist'):
        shutil.rmtree('dist')

    # Regenerate the Prisma client BEFORE tsc. The app imports
    # ../generated/prisma/client (compiled into dist/), so a stale client —
    # generated before a schema change — would ship in the zip and fail at
    # runtime with "Unknown field" on every query using the new fields. The
    # server-side `npx prisma generate` in startup.js regenerates
    # src/generated, which the runtime never imports; the zip must carry a
    # client that already matches the bundled schema.
    print("Regenerating Prisma client...")
    result = subprocess.run('npx prisma generate', shell=True, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        print("\n=== PRISMA GENERATE FAILED — aborting deploy. ===")
        sys.exit(1)

    print("Building backend (tsc)...")
    result = subprocess.run('npm run build', shell=True, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode != 0:
        print("\n=== BUILD FAILED — aborting deploy. ===")
        sys.exit(1)

def create_zip():
    zip_filename = 'deploy.zip'
    if os.path.exists(zip_filename):
        os.remove(zip_filename)
        
    include_folders = ['dist', 'prisma', 'node_modules']
    include_files = ['package.json', 'package-lock.json', 'tsconfig.json', 'startup.js']
    
    excluded_count = 0
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Write individual files (filtered)
        for filename in include_files:
            if os.path.exists(filename):
                arc = filename.replace('\\', '/')
                if should_exclude(arc):
                    print(f"Skipping excluded file: {filename}")
                    excluded_count += 1
                    continue
                zipf.write(filename, arc)
                print(f"Added file: {filename}")

        # Write directories recursively (filtered)
        for folder in include_folders:
            if not os.path.exists(folder):
                print(f"Warning: folder not found, skipping: {folder}")
                continue
            for root, dirs, files in os.walk(folder):
                # Exclude .git inside node_modules etc.
                dirs[:] = [d for d in dirs if not should_exclude(os.path.join(root, d).replace('\\','/'))]
                for file in files:
                    full_path = os.path.join(root, file)
                    archive_name = os.path.relpath(full_path, '.')
                    archive_name = archive_name.replace('\\', '/')
                    if should_exclude(archive_name):
                        excluded_count += 1
                        continue
                    # Extra hard-exclude .env / .jks anywhere
                    if archive_name.endswith('.env') or '.env.' in archive_name or archive_name.endswith('.jks') or archive_name.endswith('.keystore'):
                        excluded_count += 1
                        continue
                    zipf.write(full_path, archive_name)
                    # Verbose only for non-node_modules to avoid log spam
                    if not archive_name.startswith('node_modules/'):
                        print(f"Added file: {archive_name}")
        if excluded_count:
            print(f"Excluded {excluded_count} secret/local files from zip ( .env / *.jks / etc.)")
        # Verify no secrets leaked into zip
        try:
            with zipfile.ZipFile(zip_filename, 'r') as zr:
                names = zr.namelist()
                bad = [n for n in names if n == '.env' or n.startswith('.env.') or n.endswith('.jks') or n.endswith('.keystore') or n.endswith('.pem')]
                if bad:
                    print(f"ERROR: zip contains excluded secrets: {bad[:10]} — aborting")
                    sys.exit(1)
        except zipfile.BadZipFile as e:
            print(f"Warning: could not verify zip (BadZipFile: {e}) — continuing (zip may be large)")
        except Exception as e:
            print(f"Warning: zip verification skipped: {e}")

def poll_ready(app_name: str, resource_group: str, slot: str | None, max_wait_sec: int = 300):
    """After --async deploy, poll https://<app>.azurewebsites.net/api/ready until 200."""
    import urllib.request
    import urllib.error
    import json

    # Resolve host name via az CLI
    host = None
    try:
        slot_arg = f" --slot {slot}" if slot else ""
        cmd = f"az webapp show --name {app_name} --resource-group {resource_group}{slot_arg} --query defaultHostName -o tsv"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        host = result.stdout.strip()
    except Exception as e:
        print(f"Could not resolve host for polling: {e}")
        return

    if not host:
        print("Could not determine hostName, skipping /api/ready poll")
        return

    # If slot, host is slot host (e.g. app-staging.azurewebsites.net)
    url = f"https://{host}/api/ready"
    print(f"Polling {url} for readiness (max {max_wait_sec}s)...")
    start = time.time()
    attempt = 0
    while time.time() - start < max_wait_sec:
        attempt += 1
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "deploy-poller/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                body = resp.read().decode('utf-8', errors='ignore')[:2000]
                if resp.status == 200:
                    print(f"✓ /api/ready 200 on attempt {attempt} after {int(time.time()-start)}s: {body[:200]}")
                    return
                else:
                    print(f"  attempt {attempt}: {resp.status} — {body[:200]}")
        except urllib.error.HTTPError as e:
            body = ""
            try: body = e.read().decode('utf-8', errors='ignore')[:200]
            except: pass
            print(f"  attempt {attempt}: HTTP {e.code} — {body[:120]}")
        except Exception as e:
            print(f"  attempt {attempt}: {e}")
        time.sleep(10)
    print(f"⚠ Poll timeout after {max_wait_sec}s — check `az webapp log tail` and /api/ready manually")

def deploy():
    parser = argparse.ArgumentParser(description="Deploy Nexus Edu backend to Azure App Service via zip deploy")
    parser.add_argument('--slot', dest='slot', default=os.environ.get('DEPLOY_SLOT', ''), help='Deployment slot name (e.g. staging). If set, deploys to slot and leaves production untouched until swap.')
    parser.add_argument('--resource-group', dest='rg', default=os.environ.get('AZURE_RESOURCE_GROUP', 'nexus-edu-prod'))
    parser.add_argument('--name', dest='app', default=os.environ.get('AZURE_WEBAPP_NAME', 'nexus-edu-backend'))
    parser.add_argument('--no-poll', action='store_true', help='Skip /api/ready polling after async deploy')
    parser.add_argument('--poll-timeout', type=int, default=300, help='Seconds to poll /api/ready')
    # Allow unknown args for backwards compat (script historically took no args)
    args, _ = parser.parse_known_args()
    slot = args.slot.strip() or None

    build()
    print("Zipping backend files (excluding .env / *.jks / secrets)...")
    create_zip()
    print("Zip created successfully.")
    
    print(f"Deploying zip to Azure App Service: {args.app} (rg={args.rg}) slot={slot or 'production'}...")
    # Use the az CLI directly. On Windows the executable is az.cmd; shell=True
    # lets the OS resolve it from PATH.
    # --async: the zip (dist/prisma/node_modules bundled together) is large
    # enough that Kudu's extraction routinely outlives az CLI's synchronous
    # wait, which then reports a false "504 Gateway Timeout" even though the
    # deployment keeps going server-side. Async just pushes the artifact and
    # exits; poll `az webapp log deployment show` separately for real status.
    slot_arg = f" --slot {slot}" if slot else ""
    cmd = (
        f'az webapp deploy '
        f'--resource-group {args.rg} '
        f'--name {args.app} '
        f'--src-path deploy.zip '
        f'--type zip '
        f'--async true'
        f'{slot_arg}'
    )

    result = subprocess.run(cmd, shell=True, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode == 0:
        print("\n=== ZIP PUSH ACCEPTED (async) — polling /api/ready ===" if not args.no_poll else "\n=== DEPLOYMENT PUSH ACCEPTED (async) ===")
        if slot:
            print(f"Slot '{slot}' deployed. To swap to production: az webapp deployment slot swap --name {args.app} --resource-group {args.rg} --slot {slot} --target-slot production")
        if not args.no_poll:
            # Give Kudu a moment to unzip before polling
            time.sleep(15)
            poll_ready(args.app, args.rg, slot, max_wait_sec=args.poll_timeout)
            # Also show deployment status
            try:
                status_cmd = f"az webapp log deployment show --name {args.app} --resource-group {args.rg}{slot_arg} --query '[0].{{status:status,message:message}}' -o json"
                subprocess.run(status_cmd, shell=True, timeout=20)
            except: pass
            print("\n=== DEPLOYMENT POLL COMPLETE — verify /api/ready above ===")
    else:
        print("\n=== DEPLOYMENT FAILED! ===")
        sys.exit(result.returncode)

if __name__ == '__main__':
    deploy()
