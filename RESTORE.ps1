# Nexus Edu — One-Click Restore after PC Format
# Place this file + your 2 backup files in same folder, then run:  powershell -ExecutionPolicy Bypass -File RESTORE.ps1

param(
  [string]$VaultPath = "E:\Projects\nexus-edu-SECURE-VAULT-2026-08-22.7z",
  [string]$FullBackup = "E:\Projects\nexus-edu-FULL-FILTERED-2026-08-22.7z",
  [string]$ProjectDir = "E:\Projects\nexus_edu",
  [string]$Password = "" # will prompt if empty
)

if (-not $Password) { $Password = Read-Host -AsSecureString "Enter backup password (Lu2f6...)" | ConvertFrom-SecureString -AsPlainText }

$sevenZip = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) { Write-Error "7-Zip not found at $sevenZip — install from https://7-zip.org"; exit 1 }

# 1. Clone code (private repo) — no secrets needed
if (-not (Test-Path $ProjectDir)) {
  Write-Host "Cloning NexusEdu private repo..."
  git clone https://github.com/MasterJi27/NexusEdu.git $ProjectDir
}
Set-Location $ProjectDir

# 2. Restore secrets vault (5 files: .env, backend/.env, key.properties, 2x .jks)
Write-Host "Restoring secrets vault..."
& $sevenZip x -y -p"$Password" "$VaultPath" -o"$ProjectDir" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "Vault password wrong or vault missing"; exit 1 }
Write-Host "✓ Secrets restored: .env, backend/.env, android/key.properties, *.jks" -ForegroundColor Green

# 3. Restore full filtered backup if present (optional — otherwise git clone is enough)
if (Test-Path $FullBackup) {
  Write-Host "Restoring full filtered backup (source files)..."
  & $sevenZip x -y -p"$Password" "$FullBackup" -o"E:\Projects\" 2>&1 | Out-Null
  Write-Host "✓ Full source restored" -ForegroundColor Green
}

# 4. Rebuild regenerable (one command)
Write-Host "Installing deps..."
flutter pub get
npm --prefix backend ci
npx --prefix backend prisma generate
Write-Host "`n✓ Done — run: flutter build appbundle --release  (AAB at build\app\outputs\bundle\release\app-release.aab) and backend: npm --prefix backend run dev" -ForegroundColor Green
Write-Host "Play Store: upload E:\Projects\nexus_edu\build\app\outputs\bundle\release\app-release.aab as 1.6.1+28 update" -ForegroundColor Cyan
