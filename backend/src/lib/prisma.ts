import { PrismaClient } from '../generated/prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

// Tuned for 1M scale: max 20 connections per instance to avoid DB exhaustion
// under burst load. Use PgBouncer (transaction mode) in production in front of
// Postgres and a read replica for heavy read paths (e.g. leaderboard via
// prismaRead) to keep the primary write pool isolated.
export const prisma = new PrismaClient({
  adapter: new PrismaPg({
    connectionString: process.env.DATABASE_URL!,
    max: 20,
    idleTimeoutMillis: 10000,
    connectionTimeoutMillis: 2000,
  }),
});

export default prisma;
