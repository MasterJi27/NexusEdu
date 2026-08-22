-- IM (Institute Manager) / HOD roles: add the permission grants column.

ALTER TABLE "User" ADD COLUMN "imPermissions" JSONB;
