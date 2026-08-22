# Secrets Rotation & Key Vault Migration

> **Status:** CRITICAL — `.env` files were found with live secrets committed to the working tree (and possibly git history). Do NOT edit `.env` content to scrub — rotate instead.
> Last updated: 2026-08-22

## 1. Which secrets are affected

| Key | Where currently | Rotation priority |
|-----|----------------|-------------------|
| `GEMINI_API_KEY` | `/.env:3` | **P0** — AI key, revoke immediately if ever committed |
| `GOOGLE_SERVER_CLIENT_ID` | `/.env:4`, `backend/.env.example` | P2 — client ID is not secret but keep consistent |
| `GROQ_API_KEY` | `backend/.env:5` | **P0** |
| `OPENROUTER_API_KEY` | `backend/.env:11` | **P0** |
| `COMPOSIO_API_KEY` | `backend/.env:12` | **P0** |
| `AZURE_BOT_APP_SECRET` | `backend/.env:17` | **P0** — Entra app secret |
| `AZURE_OPENAI_API_KEY` | `backend/.env:20` | **P0** |
| `AZURE_OPENAI_ENDPOINT` | `backend/.env:21` | P1 — endpoint URL (not secret alone, but paired) |
| `AZURE_SPEECH_KEY` | `backend/.env:23` | **P0** |
| `AGORA_APP_CERTIFICATE` | `backend/.env:28` | **P0** — RTC token minting secret |
| `AGORA_APP_ID` | `backend/.env:27` | P1 |
| `JWT_SECRET` | `backend/.env:2` | **P0** — rotating invalidates all sessions |
| `DATABASE_URL` | `backend/.env:1` | **P0** — Postgres password |
| `WOLFRAM_APP_ID` | `backend/.env:6` | P1 |
| `storePassword` / `keyPassword` | `android/key.properties:1-2` | **P0** — Android keystore password; compromise allows forged APK/AAB |
| `AZURE_BOT_APP_ID` / `AZURE_BOT_TENANT_ID` | `backend/.env:15-16` | P2 — non-secret identifiers |
| Any `AZURE_*_KEY/ENDPOINT` added later | `backend/src/lib/env.ts` | P0 per key |

> Rule: **ANY value that authenticates to a billable or data-bearing service is a secret**, even if the vendor calls it "API key" or "app secret".

## 2. Immediate rotation steps (do today)

### 2.1 Revoke / regenerate at the provider

1. **Google (Gemini)**: https://aistudio.google.com/app/apikey → Delete leaked `GEMINI_API_KEY` (`sk-2zRh...`), create new → never put in `/.env` again.
2. **Groq**: https://console.groq.com/keys → Delete `gsk_xwLN...`, create new.
3. **OpenRouter**: https://openrouter.ai/keys → Delete `sk-or-v1-2e9b...`, create new.
4. **Composio**: https://app.composio.dev/settings → Rotate `ak_e8c1...` → rerun `npm run composio:connect` locally with new key.
5. **Azure Bot (Entra)**: Entra ID → App registrations → `AZURE_BOT_APP_ID=1cf1da2c...` → Certificates & secrets → Delete `vTt8Q~Hry...`, New client secret (24 months) → copy once.
6. **Azure OpenAI**: Azure Portal → `nexus-ai-openai-75efd` → Keys and Endpoint → Regenerate Key 1 (or both) → update `AZURE_OPENAI_API_KEY`.
7. **Azure Speech**: Portal → Speech resource → Keys and Endpoint → Regenerate.
8. **Agora**: https://console.agora.io → Project `1d5235...` → App Certificate → Regenerate (note: invalidates existing RTC tokens until redeploy).
9. **JWT_SECRET**: Generate fresh 64-char hex: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` — plan a maintenance window; all users will be logged out.
10. **DATABASE_URL**: Azure Portal → PostgreSQL flexible server → Reset password or rotate via `psql ALTER USER postgres WITH PASSWORD '...'`; update both primary and `REPLICA_DATABASE_URL` if used.
11. **WOLFRAM_APP_ID**: https://developer.wolframalpha.com/portal/myapps → Regenerate.
12. **Android keystore (`android/key.properties:1-2`)**: `storePassword` / `keyPassword` (`YyZL6ZoR...` pattern) — generate new 24-char: `openssl rand -base64 24` or `node -e "console.log(require('crypto').randomBytes(18).toString('base64'))"`; create new keystore `keytool -genkeypair -alias nexusedu -keyalg RSA -keysize 4096 -validity 9125 -keystore upload-keystore.jks`; update local `android/key.properties` (git-ignored per `.gitignore:71`) — never commit; upload new key to Play Console → Setup → App signing → Request key upgrade; keep old `upload-keystore.jks` until Google confirms rotation.

### 2.2 Do NOT commit the new values

- Keep them in **local** `backend/.env` (git-ignored) for dev only.
- For staging/production, inject via **Azure Key Vault** (next section). Never paste secrets into Slack, PR descriptions, or `deploy.zip`.

### 2.3 Purge git history (if secrets were ever committed)

If `git log --all -p -- .env backend/.env` shows secrets, history must be rewritten:

```bash
# 1. Install gitleaks to confirm leak scope
gitleaks detect --source . --config .gitleaks.toml --verbose

# 2. Purge files from history (requires force push — coordinate with team)
git filter-repo --path .env --path backend/.env --invert-paths
# OR for a single secret string:
# git filter-repo --replace-text <(echo "sk-2zRhYKDnHsQrt49tWlFkGigyvvwyYJz68crv8z5ipYNiLMJmmOwYSff7GMJIzn7o==>REDACTED")

# 3. Force push and expire reflog
git push origin --force --all
git push origin --force --tags

# 4. Tell every contributor to re-clone (their old clones still have the secret)
```

Add branch protection to block `.env` re-addition (see `.gitleaks.toml` + pre-commit).

## 3. Move secrets to Azure Key Vault (target state)

Infrastructure already provisions Key Vault (`infra/bicep/main.bicep:keyVault` — `enableRbacAuthorization: true`, `publicNetworkAccess: Disabled`, private endpoint). App Service resolves secrets via **Key Vault references**.

### 3.1 Create / update secrets in Key Vault

```bash
RG="nexus-edu-rg"
KV="nexus-edu-kv"  # as in main.bicep
LOCATION="southeastasia"

# Example: one secret per key (repeat for each)
az keyvault secret set --vault-name $KV --name "GeminiApiKey" --value "<NEW_GEMINI_KEY>"
az keyvault secret set --vault-name $KV --name "GroqApiKey" --value "<NEW_GROQ_KEY>"
az keyvault secret set --vault-name $KV --name "OpenRouterApiKey" --value "<NEW_OPENROUTER_KEY>"
az keyvault secret set --vault-name $KV --name "ComposioApiKey" --value "<NEW_COMPOSIO_KEY>"
az keyvault secret set --vault-name $KV --name "AzureBotAppSecret" --value "<NEW_BOT_SECRET>"
az keyvault secret set --vault-name $KV --name "AzureOpenAiApiKey" --value "<NEW_AOAI_KEY>"
az keyvault secret set --vault-name $KV --name "AzureSpeechKey" --value "<NEW_SPEECH_KEY>"
az keyvault secret set --vault-name $KV --name "AgoraAppCertificate" --value "<NEW_AGORA_CERT>"
az keyvault secret set --vault-name $KV --name "JwtSecret" --value "<NEW_JWT_64HEX>"
az keyvault secret set --vault-name $KV --name "DatabaseUrl" --value "postgresql://user:<NEW_PWD>@<host>:5432/nexus_edu?sslmode=require"
az keyvault secret set --vault-name $KV --name "RedisUrl" --value "rediss://:<pwd>@<cache>.redis.cache.windows.net:6380"
```

Use `az keyvault secret set --expires` to enforce rotation cadence (e.g., 90d).

### 3.2 Wire App Service to Key Vault references (Bicep already does for some)

In `infra/bicep/main.bicep` `webApp` `appSettings`:

```bicep
{
  name: 'GROQ_API_KEY'
  value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=GroqApiKey)'
}
{
  name: 'GEMINI_API_KEY'
  value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=GeminiApiKey)'
}
{
  name: 'OPENROUTER_API_KEY'
  value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=OpenRouterApiKey)'
}
{
  name: 'AZURE_BOT_APP_SECRET'
  value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=AzureBotAppSecret)'
}
// ... repeat for every secret
```

RBAC already granted: `KeyVaultSecretsUser` to `webApp.identity.principalId` (and slot). If adding a new secret, no extra role needed.

Deploy: `az deployment group create ...` or `azd up` — App Service will resolve references at boot (no code change). Verify via:

```bash
az webapp config appsettings list -g $RG -n nexus-edu-backend --query "[?name=='GROQ_API_KEY'].value" -o tsv
# Should show: @Microsoft.KeyVault(...)
az webapp log tail -g $RG -n nexus-edu-backend  # check no "Missing required env var" on startup
curl https://<app>.azurewebsites.net/api/ready | jq .checks
```

### 3.3 Local dev without secrets in repo

- Copy `backend/.env.example` → `backend/.env` and fill from Key Vault via CLI or 1Password:

```bash
az keyvault secret show --vault-name $KV --name GroqApiKey --query value -o tsv > /tmp/groq
```

- Never `git add .env`. The `.gitignore` already ignores `.env`, `.env.*`, `*.env.local` — CI will fail if this is violated (gitleaks).

### 3.4 Rotation cadence & automation

| Secret | Cadence | Owner | Automation |
|--------|---------|-------|------------|
| JWT_SECRET | 90d or on breach | Platform | Key Vault rotation policy + App Service restart |
| DATABASE_URL | 90d | DBA | Portal rotation + update replica |
| All AI keys (Groq/Gemini/OpenRouter/Azure) | 60-90d | AI platform | `az keyvault rotation policy` |
| AGORA_APP_CERTIFICATE | on vendor guidance | Live-class | Manual regenerate |
| AZURE_BOT_APP_SECRET | Expires 24mo — rotate at 12mo | Bot team | Entra ID reminder |

Enable Key Vault **purge protection** (`enablePurgeProtection: true` already in Bicep) and **diagnostics** to Log Analytics. Set up alert on `SecretNearExpiry` event grid.

## 4. Preventing recurrence

1. **Gitleaks** — `.gitleaks.toml` at repo root runs in CI (`gitleaks detect --no-git -v`) and pre-commit hook. Catches `gsk_`, `sk-or-v1-`, `ak_`, `AIza`, `-----BEGIN PRIVATE KEY-----`, high-entropy strings.
2. **Pre-commit hook**:

```bash
pip install pre-commit
cat > .pre-commit-config.yaml <<'YAML'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
YAML
pre-commit install
```

3. **GitHub push protection**: Settings → Code security → Secret scanning → Push protection → Enable.

4. **No `.env` in PRs**: CI job fails if `git diff --name-only origin/main | grep -E '^\.env|/\.env'` matches.

5. **Least privilege**: App Service Managed Identity is `KeyVaultSecretsUser` only — no human needs vault data plane access except break-glass group.

## 5. Checklist (copy into ticket)

- [ ] Revoked all 13 affected keys at vendors
- [ ] New keys stored in Key Vault (`az keyvault secret list --vault-name $KV`)
- [ ] `infra/bicep/main.bicep` appSettings point to Key Vault references
- [ ] Deployed and `GET /api/ready` returns `ready`
- [ ] `gitleaks detect` clean
- [ ] `git filter-repo` executed and force-pushed (if history leaked)
- [ ] Team notified to re-clone
- [ ] Push protection + gitleaks CI + pre-commit enabled
- [ ] Rotation calendar event created (90d)

## 6. References

- `backend/src/lib/env.ts` — source of truth for env consumption
- `backend/.env.example` / `/.env.example` — templates (no secrets)
- `.gitignore:48-52` — `.env` ignore rules
- `.gitleaks.toml` — scan rules
- `infra/bicep/main.bicep` — Key Vault + RBAC + App Service references
