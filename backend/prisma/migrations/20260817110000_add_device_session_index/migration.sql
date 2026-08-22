-- Index for the device-binding check: how many distinct accounts are active
-- on one device (WHERE deviceId = ? AND revokedAt IS NULL).
CREATE INDEX "DeviceSession_deviceId_revokedAt_idx" ON "DeviceSession"("deviceId", "revokedAt");