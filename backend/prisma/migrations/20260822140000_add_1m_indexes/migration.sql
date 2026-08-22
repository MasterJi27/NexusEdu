-- 1M scale indexes: hot paths (leaderboard, feed, attendance, notes)
-- In production with live traffic, prefer CREATE INDEX CONCURRENTLY outside a
-- transaction for zero-downtime. This migration uses plain IF NOT EXISTS so
-- `prisma migrate deploy` (transactional) succeeds; on a large prod DB re-run
-- the CONCURRENTLY variant manually if needed.

-- User: leaderboard and tenancy filters
CREATE INDEX IF NOT EXISTS "User_role_xp_idx" ON "User"("role", "xp" DESC);
CREATE INDEX IF NOT EXISTS "User_organizationId_idx" ON "User"("organizationId");
CREATE INDEX IF NOT EXISTS "User_createdAt_idx" ON "User"("createdAt");

-- LoginLog / ActivityLog: per-user time range scans
CREATE INDEX IF NOT EXISTS "LoginLog_userId_timestamp_idx" ON "LoginLog"("userId", "timestamp");
CREATE INDEX IF NOT EXISTS "ActivityLog_userId_timestamp_idx" ON "ActivityLog"("userId", "timestamp");

-- Course: instructor feed
CREATE INDEX IF NOT EXISTS "Course_instructorId_idx" ON "Course"("instructorId");

-- Discussion / Reply: course and thread listings
CREATE INDEX IF NOT EXISTS "Discussion_courseId_idx" ON "Discussion"("courseId");
CREATE INDEX IF NOT EXISTS "Reply_discussionId_idx" ON "Reply"("discussionId");

-- TeacherNote: teacher's own note listings
CREATE INDEX IF NOT EXISTS "TeacherNote_teacherId_idx" ON "TeacherNote"("teacherId");

-- ParentLink: parent dashboard lookups
CREATE INDEX IF NOT EXISTS "ParentLink_parentId_status_idx" ON "ParentLink"("parentId", "status");

-- Section: teacher's sections ordered by recency
CREATE INDEX IF NOT EXISTS "Section_teacherId_createdAt_idx" ON "Section"("teacherId", "createdAt");

-- AttendanceRecord: session rollups
CREATE INDEX IF NOT EXISTS "AttendanceRecord_sessionId_idx" ON "AttendanceRecord"("sessionId");

-- Safe concurrent variants for manual prod runs (uncomment and run outside transaction):
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS "User_role_xp_idx" ON "User"("role", "xp" DESC);
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS "LoginLog_userId_timestamp_idx" ON "LoginLog"("userId", "timestamp");
-- etc.
