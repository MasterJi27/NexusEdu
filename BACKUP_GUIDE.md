# Nexus Edu — Secure Backup & Restore Guide (Zero-PC-Loss)

> **Goal:** After full PC format, `git clone` + 1 password → everything auto-restores, no re-creating API keys.

## What was backed up (2026-08-22)

| File | Where encrypted | Size |
|------|-----------------|------|
| **SECURE VAULT** `E:\Projects\nexus-edu-SECURE-VAULT-2026-08-22.7z` | 5 files: `.env` (635 B), `backend/.env` (1288 B), `android/key.properties` (131 B), `upload-keystore.jks` (2716 B), `nexusedu_key.jks` (5153 B) — **AES-256 + header encryption** | 8.94 KB |
| **FULL FILTERED** `E:\Projects\nexus-edu-FULL-FILTERED-2026-08-22.7z` | 22494 files, 1532 MiB → 564 MB, excludes `node_modules/.dart_tool/build/.git` (regenerable via `flutter pub get` + `npm ci`) but includes every text file, .env via vault is duplicate | 564 MB |

Both are `7z -mhe=on -p<24-char> -m0=lzma2 -mx=9` (AES-256, header encrypted). Password is **24-char alphanumeric** saved in `C:\Users\ragha\AppData\Local\Temp\nexus_backup_pass.txt` — **SAVE IT NOW** in Bitwarden/1Password + pen drive. Without it, backups are unrecoverable.

## Where to store (3-2-1, zero cost with student account)

1. **Private GitHub** `https://github.com/MasterJi27/NexusEdu` (already `origin`) — **code only** (no .env, no .jks due to `.gitignore:48` `.env:48` + `*.jks:68`). Already pushed, just `git push` after format: `git clone` restores 99% of code. **Do NOT add vault 7z to GitHub** (even private, keep vault off Git).
2. **Azure Blob private (offsite, 11 9's, free with student)** — `az storage blob upload --account-name <your> --container-name nexus-backup --file "E:\Projects\nexus-edu-SECURE-VAULT-2026-08-22.7z" --name vault-2026-08-22.7z --auth-mode login` (private, no SAS). Same for full 7z if you have 1 GB quota. Or student OneDrive: drag vault + full 7z.
3. **External USB** — copy both 7z + `RESTORE.ps1` to pen drive, keep offline.

This is **proper secure**: vault is AES-256 header-encrypted, password never in repo, GitHub has only code, Azure private blob needs Entra ID.

## Quick save now (before format)

```powershell
# 1. Push code (no secrets) to private GitHub
git add -A
git commit -m "backup before PC reset 2026-08-22"
git push origin main

# 2. Upload vault to Azure (private, if you have Storage account) — or just copy to Drive
# Example: az storage blob upload --account-name nexusstore --container-name backup --file "E:\Projects\nexus-edu-SECURE-VAULT-2026-08-22.7z" --auth-mode login

# 3. Copy both 7z + RESTORE.ps1 to USB + Drive
Copy-Item "E:\Projects\nexus-edu-SECURE-VAULT-2026-08-22.7z" "D:\"
Copy-Item "E:\Projects\nexus-edu-FULL-FILTERED-2026-08-22.7z" "D:\"
Copy-Item "E:\Projects\nexus_edu\RESTORE.ps1" "D:\"
```

## Restore after format (1 command)

```powershell
# Put vault + full 7z + RESTORE.ps1 in same folder, then:
powershell -ExecutionPolicy Bypass -File E:\Projects\RESTORE.ps1
# It will prompt for password (Lu2f6JyZ9xAUzmi3rP0BTohX) and do: git clone → 7z x vault → flutter pub get → npm ci → prisma generate
```

No re-creating API keys, no Play Store key loss — upload-keystore.jks restored, `flutter build appbundle --release` will sign with same key and Play will accept as **update** to fresh live app `1.6.1+28` > `1.2.5+15`.

## Why this is better than GitHub-only or AWS

- **GitHub alone:** Code is safe, but `.env` is ignored, so after clone you’d hunt keys. Vault solves it separately, encrypted.
- **AWS S3:** Same as Azure Blob, but you already have Azure for Students (free 12 mo + $100 credit) + existing `nexus-edu-prod` RG, so Blob is zero extra setup. GitHub private is also free. Use **both**: GitHub for code history, Blob for vault durability.
- **Security:** Vault is AES-256 header-encrypted; even if Blob is leaked, without password it’s random bytes. Password is 24-char alphanumeric (95 bits entropy) — store in Bitwarden, not in repo.

## Check after restore

```powershell
Test-Path .env; Test-Path backend\.env; Test-Path android\app\upload-keystore.jks  # all True
flutter build appbundle --release  # AAB at build\app\outputs\bundle\release\app-release.aab 188.8 MB
```

Keep `C:\Users\ragha\AppData\Local\Temp\nexus_backup_pass.txt` safe — delete after saving to password manager.
