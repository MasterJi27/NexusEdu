# =============================================================================
# Nexus Edu Backend — multi-stage Dockerfile (1M hardening)
# - Stage `build` compiles TypeScript + generates Prisma client (cached layer)
# - Stage `runtime` is minimal Alpine with non-root user, tini init, healthcheck,
#   read-only-friendly layout for 1M scale (3-30 replicas behind Front Door)
# =============================================================================

FROM node:20.11.3-alpine3.19@sha256:13fe0cdb15c64d7a1608951360316824c24cb303bc4243f9e6b3cf5d187ffd79 AS build
WORKDIR /app

# 1M: leverage Docker layer cache — install deps before copying source so
# rebuilds on .ts changes don't reinstall 200+ MB node_modules.
COPY package.json package-lock.json* ./
RUN npm ci --ignore-scripts

# Copy source needed for `tsc` + `prisma generate`. `.dockerignore` excludes
# node_modules, dist, .git, NexusEdu_new_release_assets, etc.
COPY tsconfig.json prisma.config.ts ./
COPY prisma ./prisma
COPY src ./src
COPY startup.js ./

# Generate Prisma client into src/generated/prisma (matches schema.prisma
# `output`) then compile TypeScript to dist/. `postinstall` is skipped above,
# so we run generate explicitly here.
RUN npx prisma generate && npm run build

# Prune devDependencies so the runtime image doesn't ship vitest/ts-node.
# Keep `prisma` CLI for `startup.js` migrate-deploy fallback.
RUN npm prune --production

# -----------------------------------------------------------------------------
FROM node:20.11.3-alpine3.19@sha256:13fe0cdb15c64d7a1608951360316824c24cb303bc4243f9e6b3cf5d187ffd79
WORKDIR /app

ENV NODE_ENV=production
# 1M: App Service injects PORT; fallback 3000 for local `docker run`.
ENV PORT=3000
ENV NODE_OPTIONS=--max-old-space-size=1536
# 1M: prevent npm update notifier / ensure production behavior
ENV NPM_CONFIG_UPDATE_NOTIFIER=false

# 1M: tini as dumb-init for proper SIGTERM forwarding + zombie reaping; wget for HEALTHCHECK
RUN apk add --no-cache tini wget

# 1M: run as non-root — CIS hardened, limits container breakout blast radius.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only what the runtime needs — no src/, no .ts, no dev deps.
# Use COPY --chown to avoid extra chown layer and ensure correct ownership at copy time.
COPY --from=build --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=build --chown=appuser:appgroup /app/dist ./dist
COPY --from=build --chown=appuser:appgroup /app/package.json ./package.json
COPY --from=build --chown=appuser:appgroup /app/prisma ./prisma
COPY --from=build --chown=appuser:appgroup /app/startup.js ./startup.js

# Prisma schema is needed at runtime for `migrate deploy` fallback in startup.js
# (schema.prisma lives under prisma/ after build).

# Ensure correct ownership for runtime writable paths (Prisma generation temp, logs)
RUN mkdir -p /app/src/generated && chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

# 1M: readiness probe — hits /api/ready (DB + Redis check). Healthy = in rotation
# Interval 10s for fast detection, timeout 5s, retries 3, start-period 30s to allow migrations.
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=30s CMD wget -qO- http://localhost:$${PORT:-3000}/api/ready || exit 1

# Use tini as init to properly handle SIGTERM/SIGINT and reap zombies
ENTRYPOINT ["/sbin/tini", "--"]
# startup.js runs `migrate deploy` flock-guarded then `require('./dist/index.js')`
CMD ["node", "startup.js"]
