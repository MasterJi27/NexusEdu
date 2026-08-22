-- AlterTable
ALTER TABLE "ClassTaskSubmission" ADD COLUMN "content" TEXT;
ALTER TABLE "ClassTaskSubmission" ADD COLUMN "grade" DOUBLE PRECISION;
ALTER TABLE "ClassTaskSubmission" ADD COLUMN "feedback" TEXT;
ALTER TABLE "ClassTaskSubmission" ADD COLUMN "gradedAt" TIMESTAMP(3);
