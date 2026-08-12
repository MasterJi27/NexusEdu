-- Enforce account/device policy at the backend layer.
-- One user can have at most the configured number of active DeviceSession rows;
-- the API currently caps this at 2 active sessions per account.

CREATE TABLE IF NOT EXISTS "DeviceSession" (
  "id" TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  "deviceId" TEXT NOT NULL,
  "deviceName" TEXT,
  "userAgent" TEXT,
  "ipAddress" TEXT,
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "revokedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "DeviceSession_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "DeviceSession_userId_deviceId_key"
  ON "DeviceSession"("userId", "deviceId");

CREATE INDEX IF NOT EXISTS "DeviceSession_userId_revokedAt_lastSeenAt_idx"
  ON "DeviceSession"("userId", "revokedAt", "lastSeenAt");
