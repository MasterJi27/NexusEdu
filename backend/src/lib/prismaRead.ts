import { PrismaClient } from '../generated/prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

// Read replica for 1M scale: heavy read paths (leaderboard, feed, search)
// should use prismaRead so primary stays write-isolated. Falls back to the
// primary DATABASE_URL when REPLICA_DATABASE_URL is not configured (single-DB
// dev / early prod), so callers never need a conditional import.
const replicaUrl = process.env.REPLICA_DATABASE_URL || process.env.DATABASE_URL!;

const replicaAdapter = new PrismaPg({
  connectionString: replicaUrl,
  max: 20,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 2000,
});

export const prismaRead = new PrismaClient({ adapter: replicaAdapter });

export default prismaRead;
