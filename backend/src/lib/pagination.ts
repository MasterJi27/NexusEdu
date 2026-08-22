export function parsePagination(query: any, max = 50) {
  let p = parseInt(query.limit);
  if (!Number.isFinite(p)) p = 20;
  const limit = Math.min(Math.max(p, 1), max);
  const cursor = query.cursor as string | undefined;
  if (cursor != null && cursor !== '' && !/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(cursor)) {
    const err: any = new Error('Invalid cursor — must be a UUID');
    err.status = 400;
    throw err;
  }
  let o = parseInt(query.offset ?? '0');
  if (!Number.isFinite(o)) o = 0;
  const offset = Math.max(o, 0);
  return { limit, cursor, offset };
}
