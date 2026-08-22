-- Add optional inline image sharing to live class chat
ALTER TABLE "LiveChatMessage" ADD COLUMN "imageData" TEXT;
