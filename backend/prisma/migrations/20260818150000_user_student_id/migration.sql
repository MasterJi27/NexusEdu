-- Unique school admission number for students (roll numbers repeat across sections)
ALTER TABLE "User" ADD COLUMN "studentId" TEXT;
CREATE UNIQUE INDEX "User_studentId_key" ON "User"("studentId") WHERE "studentId" IS NOT NULL;
