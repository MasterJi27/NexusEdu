-- ImportedChat: conversations imported from other chat apps (ChatGPT export)
CREATE TABLE "ImportedChat" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'chatgpt',
    "title" TEXT NOT NULL,
    "messages" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ImportedChat_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ImportedChat_userId_idx" ON "ImportedChat"("userId");