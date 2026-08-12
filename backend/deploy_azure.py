import os
import shutil
import zipfile
import subprocess
import sys

def build():
    # dist/ is gitignored and never rebuilt by this script on its own — a
    # stale dist/ (e.g. containing a route file already deleted from src/)
    # would get zipped and deployed as-is. tsc also never deletes output for
    # source files that were removed, so dist/ is wiped first, not just
    # overwritten.
    print("Cleaning previous build output...")
    if os.path.exists('dist'):
        shutil.rmtree('dist')

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
    
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Write individual files
        for filename in include_files:
            if os.path.exists(filename):
                zipf.write(filename, filename.replace('\\', '/'))
                print(f"Added file: {filename}")
                
        # Write directories recursively
        for folder in include_folders:
            for root, dirs, files in os.walk(folder):
                for file in files:
                    full_path = os.path.join(root, file)
                    archive_name = os.path.relpath(full_path, '.')
                    archive_name = archive_name.replace('\\', '/')
                    zipf.write(full_path, archive_name)
                    print(f"Added file: {archive_name}")

def deploy():
    build()
    print("Zipping backend files...")
    create_zip()
    print("Zip created successfully.")
    
    print("Deploying zip to Azure App Service...")
    # Use the az CLI directly. On Windows the executable is az.cmd; shell=True
    # lets the OS resolve it from PATH.
    # --async: the zip (dist/prisma/node_modules bundled together) is large
    # enough that Kudu's extraction routinely outlives az CLI's synchronous
    # wait, which then reports a false "504 Gateway Timeout" even though the
    # deployment keeps going server-side. Async just pushes the artifact and
    # exits; poll `az webapp log deployment show` separately for real status.
    cmd = (
        'az webapp deploy '
        '--resource-group nexus-edu-prod '
        '--name nexus-edu-backend '
        '--src-path deploy.zip '
        '--type zip '
        '--async true'
    )

    result = subprocess.run(cmd, shell=True, stdout=sys.stdout, stderr=sys.stderr)
    if result.returncode == 0:
        print("\n=== DEPLOYMENT SUCCESSFUL! ===")
    else:
        print("\n=== DEPLOYMENT FAILED! ===")

if __name__ == '__main__':
    deploy()
