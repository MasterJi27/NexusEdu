-- Organization multi-tenancy: introduce Organization model without breaking existing data
-- Backfill: existing User.organizationName/orgLogoUrl/accentColor retained for migration (deprecated, nullable)
-- No automatic data migration: future script will CREATE Organization per distinct legacy organizationName and link members/sections

-- CreateTable
CREATE TABLE "Organization" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "logoUrl" TEXT,
    "accentColor" TEXT,
    "inviteCode" TEXT,
    "domain" TEXT,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Organization_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Organization_name_key" ON "Organization"("name");
CREATE UNIQUE INDEX "Organization_slug_key" ON "Organization"("slug");
CREATE UNIQUE INDEX "Organization_inviteCode_key" ON "Organization"("inviteCode") WHERE "inviteCode" IS NOT NULL;
CREATE INDEX "Organization_slug_idx" ON "Organization"("slug");

-- AlterTable: add nullable FK columns for backward compatibility (existing rows stay NULL)
ALTER TABLE "User" ADD COLUMN "organizationId" TEXT;
ALTER TABLE "Section" ADD COLUMN "organizationId" TEXT;

-- AddForeignKey
ALTER TABLE "Organization" ADD CONSTRAINT "Organization_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "User" ADD CONSTRAINT "User_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Section" ADD CONSTRAINT "Section_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateIndex
CREATE INDEX "Section_organizationId_idx" ON "Section"("organizationId");
CREATE INDEX "User_organizationId_idx" ON "User"("organizationId");

-- Backfill comment: no data copied yet; legacy columns organizationName/orgLogoUrl/accentColor remain on User for migration period.
-- Future backfill example (not executed automatically):
-- INSERT INTO "Organization" ("id", "name", "slug", "logoUrl", "accentColor", "createdById", "createdAt", "updatedAt")
-- SELECT gen_random_uuid()::text, "organizationName", lower(regexp_replace("organizationName", '\s+', '-', 'g')), "orgLogoUrl", "accentColor", "id", NOW(), NOW()
-- FROM "User" WHERE "organizationName" IS NOT NULL GROUP BY "organizationName", "orgLogoUrl", "accentColor", "id";
