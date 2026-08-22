-- CreateTable
CREATE TABLE "LiveBoardEvent" (
    "id" TEXT NOT NULL,
    "liveSessionId" TEXT NOT NULL,
    "seq" SERIAL NOT NULL,
    "type" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "LiveBoardEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "LiveBoardEvent_liveSessionId_seq_idx" ON "LiveBoardEvent"("liveSessionId", "seq");

-- AddForeignKey
ALTER TABLE "LiveBoardEvent" ADD CONSTRAINT "LiveBoardEvent_liveSessionId_fkey" FOREIGN KEY ("liveSessionId") REFERENCES "LiveSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;