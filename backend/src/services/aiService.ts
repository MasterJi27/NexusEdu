import prisma from '../lib/prisma';
import { env } from '../lib/env';

const GROQ_BASE_URL = 'https://api.groq.com/openai/v1/chat/completions';

interface AiTarget {
  provider: 'groq' | 'azure';
  url: string;
  model: string;
  key: string | undefined;
  headers: Record<string, string>;
}

/**
 * OpenAI-compatible chat target: Azure OpenAI when its env vars are set,
 * otherwise Groq (existing behaviour). Both speak the same wire protocol, so
 * every route keeps working unchanged.
 */
function chatTarget(): AiTarget {
  const { AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_KEY, AZURE_OPENAI_DEPLOYMENT } = env;
  if (AZURE_OPENAI_ENDPOINT && AZURE_OPENAI_API_KEY && AZURE_OPENAI_DEPLOYMENT) {
    const host = AZURE_OPENAI_ENDPOINT.replace(/^https?:\/\//, '').replace(/\/+$/, '');
    return {
      provider: 'azure',
      url: `https://${host}/openai/deployments/${AZURE_OPENAI_DEPLOYMENT}/chat/completions?api-version=2024-10-21`,
      model: AZURE_OPENAI_DEPLOYMENT,
      key: AZURE_OPENAI_API_KEY,
      headers: { 'api-key': AZURE_OPENAI_API_KEY },
    };
  }
  return {
    provider: 'groq',
    url: GROQ_BASE_URL,
    model: aiConfig.model,
    key: env.GROQ_API_KEY,
    headers: { Authorization: `Bearer ${env.GROQ_API_KEY}` },
  };
}

/**
 * Centralized AI configuration. Model, prompts and quota live here so routes
 * stay thin and behaviour is consistent across every AI endpoint.
 */
export const aiConfig = {
  // llama-3.1-8b-instant: free tier (30 req/min, 6000 TPM) and the lowest
  // latency model on the provider (~100ms first token). Override via AI_MODEL.
  model: process.env.AI_MODEL || 'llama-3.1-8b-instant',
  defaultTemperature: 0.7,
  dailyQuotaTokens: Number(process.env.DAILY_AI_QUOTA_TOKENS || 200_000),
  resetQuotaEveryDay: true,
};

/**
 * System prompts per feature. Keeping them here makes them easy to audit and
 * tune without hunting through route handlers.
 */
export const systemPrompts = {
  tutor:
    'You are Nexus, the friendly AI Tutor for Indian students (CBSE, ICSE, JEE, NEET). ' +
    'Always respond in clear English, be encouraging and concise. ' +
    'Break complex topics into simple steps with relatable examples. ' +
    'Use clean Markdown: short paragraphs, bullet points and math in LaTeX blocks ($$...$$) when needed. ' +
    'If a question is off-topic or harmful, politely steer the student back to learning.',
  math:
    'You are an expert Math Tutor for Indian students (JEE/NEET/CBSE). ' +
    'Given the student\'s problem and the step-by-step solution from Wolfram Alpha, ' +
    'explain it simply using clean Markdown and LaTeX math blocks. ' +
    'Show every step, mention the formula used, and end with one encouraging line. Be concise.',
  general:
    'You are Nexus, an AI study assistant for Indian students. ' +
    'Answer in clear, simple English. Prefer Markdown formatting. Be concise, accurate and encouraging. ' +
    'If asked something harmful or off-topic, steer back to academics.',
};

export type AiFeature =
  | keyof typeof systemPrompts
  | 'custom'
  | 'tutor-stream'
  | 'solve-math'
  | 'agent'
  | 'quiz'
  | 'grader'
  | 'parent-digest';

export interface UsageRecord {
  userId: string;
  feature: string;
  model: string;
  endpoint: string;
  promptTokens: number;
  completionTokens: number;
  latencyMs?: number;
  status?: string;
  error?: string;
}

/** Persist one AI call's usage so we can report tokens per user/feature/day. */
export async function trackAiUsage(record: UsageRecord): Promise<void> {
  try {
    await prisma.aiUsageLog.create({
      data: {
        userId: record.userId,
        feature: record.feature,
        model: record.model,
        endpoint: record.endpoint,
        promptTokens: record.promptTokens,
        completionTokens: record.completionTokens,
        totalTokens: record.promptTokens + record.completionTokens,
        latencyMs: record.latencyMs,
        status: record.status || 'success',
        error: record.error,
      },
    });
  } catch (error) {
    console.error('Failed to persist AI usage:', error);
  }
}

/* ---------------------------------------------------------------------------
 * Token-bucket AI quota
 * ---------------------------------------------------------------------------
 * The user's AI budget is a continuous-refill token bucket, not a fixed
 * window: capacity = one day's budget, refill = capacity/86400 per second.
 * Tokens accrue smoothly (there is nothing to game at minute or hour
 * boundaries), bursts can never exceed capacity, and there is no midnight
 * reset — the balance simply clamps at capacity. Two small buckets per user
 * share one row: `tokens` (the business budget) and `requests` (call rate).
 * Every update is a single guarded SQL statement, so concurrent requests can
 * never double-spend: the UPDATE ... WHERE "tokens" >= x guard re-evaluates
 * per row under Postgres row locking.
 * ------------------------------------------------------------------------- */
const bucketConfig = (() => {
  const pick = (v: string | undefined, fallback: number) => {
    const p = v === undefined ? NaN : Number(v);
    return Number.isFinite(p) && p > 0 ? p : fallback;
  };
  const capacity = pick(process.env.AI_BUCKET_CAPACITY, aiConfig.dailyQuotaTokens);
  return {
    capacity,
    refillRate: pick(process.env.AI_BUCKET_REFILL_PER_SECOND, capacity / 86_400),
    requestCapacity: pick(process.env.AI_BUCKET_REQUEST_CAPACITY, 30),
    requestRefillRate: pick(
      process.env.AI_BUCKET_REQUEST_REFILL_PER_SECOND,
      1 / 15,
    ),
  };
})();

/** Lazily create the bucket row on first use. */
async function ensureBucket(userId: string): Promise<void> {
  const c = bucketConfig;
  await prisma.aiTokenBucket.upsert({
    where: { userId },
    create: {
      userId,
      capacity: c.capacity,
      refillRate: c.refillRate,
      requestCapacity: c.requestCapacity,
      requestRefillRate: c.requestRefillRate,
    },
    update: {},
  });
}

/** Apply the continuous refill since the last update (single atomic UPDATE). */
async function refillBucket(userId: string): Promise<void> {
  const c = bucketConfig;
  await prisma.$executeRaw`
    UPDATE "AiTokenBucket"
    SET
      "tokens" = LEAST("capacity", "tokens" + EXTRACT(EPOCH FROM (now() - "lastRefillAt")) * "refillRate"),
      "requests" = LEAST("requestCapacity", ("requests" + EXTRACT(EPOCH FROM (now() - "lastRefillAt")) * "requestRefillRate")::int),
      "lastRefillAt" = now(),
      "capacity" = ${c.capacity},
      "refillRate" = ${c.refillRate},
      "requestCapacity" = ${c.requestCapacity},
      "requestRefillRate" = ${c.requestRefillRate}
    WHERE "userId" = ${userId}
  `;
}

async function readBucket(userId: string) {
  const row = await prisma.aiTokenBucket.findUniqueOrThrow({
    where: { userId },
  });
  return {
    tokens: Math.floor(row.tokens),
    capacity: row.capacity,
    requests: row.requests,
    requestCapacity: row.requestCapacity,
    refillRate: row.refillRate,
    requestRefillRate: row.requestRefillRate,
  };
}

/**
 * Business rule: every user has a token bucket for AI. Returns
 * { allowed, remainingToday, quota } — callers return 429 when not allowed.
 */
export async function getAiQuota(userId: string) {
  await ensureBucket(userId);
  await refillBucket(userId);
  const b = await readBucket(userId);
  return {
    allowed: b.tokens >= 1,
    quota: Math.floor(b.capacity),
    usedTokens: Math.max(0, Math.floor(b.capacity - b.tokens)),
    usedRequests: Math.max(0, b.requestCapacity - b.requests),
    remainingTokens: b.tokens,
  };
}

export interface QuotaReservation {
  allowed: boolean;
  quota: number;
  usedTokens: number;
  usedRequests: number;
  remainingTokens: number;
  reservedTokens: number;
}

/**
 * Atomically reserve [estimatedTokens] from the user's bucket. The
 * UPDATE ... WHERE "tokens" >= reservation guard is what makes concurrent
 * requests race-safe: with Postgres row locking, the second request
 * re-evaluates the guard against the first's committed decrement and gets
 * refused instead of both passing a check-then-use race.
 */
export async function reserveQuota(
  userId: string,
  estimatedTokens: number,
): Promise<QuotaReservation> {
  await ensureBucket(userId);
  await refillBucket(userId);

  const reservation = Math.max(1, Math.min(Math.ceil(estimatedTokens), 100_000));

  const took = await prisma.$executeRaw`
    UPDATE "AiTokenBucket"
    SET "tokens" = "tokens" - ${reservation}
    WHERE "userId" = ${userId} AND "tokens" >= ${reservation}
  `;

  const b = await readBucket(userId);
  const allowed = took === 1;
  return {
    allowed,
    quota: Math.floor(b.capacity),
    usedTokens: Math.max(0, Math.floor(b.capacity - b.tokens)),
    usedRequests: Math.max(0, b.requestCapacity - b.requests),
    remainingTokens: b.tokens,
    reservedTokens: allowed ? reservation : 0,
  };
}

/**
 * Refund whatever the reservation did not use (streams usually consume less
 * than the estimate). Never throws — quota must not break an already
 * successful response.
 */
export async function settleQuota(
  userId: string,
  reservedTokens: number,
  actualTokens: number,
): Promise<void> {
  try {
    const unused = Math.max(0, reservedTokens - Math.ceil(actualTokens));
    if (unused === 0) return;
    await prisma.$executeRaw`
      UPDATE "AiTokenBucket"
      SET "tokens" = LEAST("capacity", "tokens" + ${unused})
      WHERE "userId" = ${userId}
    `;
  } catch (error) {
    console.error('Failed to settle AI quota:', error);
  }
}

/**
 * Per-request rate control: drain the request bucket continuously (capacity
 * 30, ~1 refill per 15 s). Replaces fixed-window request limiting, so a
 * burst can never line up with a window edge for a free refill.
 */
export async function consumeAiRequest(
  userId: string,
): Promise<{ allowed: boolean; retryAfterSeconds: number }> {
  await ensureBucket(userId);
  await refillBucket(userId);

  const took = await prisma.$executeRaw`
    UPDATE "AiTokenBucket"
    SET "requests" = "requests" - 1
    WHERE "userId" = ${userId} AND "requests" >= 1
  `;

  if (took === 1) return { allowed: true, retryAfterSeconds: 0 };
  const b = await readBucket(userId);
  const needed = Math.max(1, 1 - b.requests);
  return {
    allowed: false,
    retryAfterSeconds: Math.max(1, Math.ceil(needed / b.requestRefillRate)),
  };
}

export interface ChatOptions {
  messages: { role: string; content: any; name?: string; tool_call_id?: string; tool_calls?: unknown[] }[];
  temperature?: number;
  maxTokens?: number;
  feature?: AiFeature;
  userId?: string;
  /** Emit structured JSON only (provider JSON mode). */
  jsonMode?: boolean;
  /** Tool definitions for function calling. */
  tools?: unknown[];
  /** Model override (Groq only). Used e.g. for vision-capable models. */
  model?: string;
}

interface GroqToolCall {
  id: string;
  type: 'function';
  function: { name: string; arguments: string };
}

interface GroqMessage {
  content: string | null;
  tool_calls?: GroqToolCall[];
}

interface GroqSuccess {
  choices: { message: GroqMessage }[];
  usage?: { prompt_tokens: number; completion_tokens: number; total_tokens: number };
}

/**
 * Single Groq call path used by every endpoint. Reserves quota atomically,
 * calls the model, records usage, settles the reservation. Throws on quota
 * exceeded / upstream failure (refunding the reservation on failure).
 */
export async function groqChat(options: ChatOptions): Promise<GroqSuccess> {
  const {
    messages,
    temperature = aiConfig.defaultTemperature,
    maxTokens = 2048,
    feature = 'general',
    userId,
    jsonMode,
    tools,
    model,
  } = options;

  let reserved = 0;
  if (userId) {
    const reservation = await reserveQuota(userId, maxTokens);
    reserved = reservation.reservedTokens;
    if (!reservation.allowed) {
      const error = new Error(
        `AI token budget exhausted (${reservation.remainingTokens} tokens left — refills continuously).`,
      );
      (error as any).statusCode = 429;
      (error as any).quota = reservation;
      throw error;
    }
  }

  const target = chatTarget();
  if (!target.key) {
    if (userId) await settleQuota(userId, reserved, 0);
    const error = new Error(
      target.provider === 'azure' ? 'AZURE_OPENAI_API_KEY is not configured' : 'GROQ_API_KEY is not configured',
    );
    (error as any).statusCode = 503;
    throw error;
  }

  // Per-call model override only applies to Groq (Azure deploys are fixed
  // deployments whose name is the model id there).
  const effectiveModel = model && target.provider === 'groq' ? model : target.model;

  const startedAt = Date.now();
  let response: Response;
  try {
    response = await fetch(target.url, {
      method: 'POST',
      headers: { ...target.headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: effectiveModel,
        messages,
        temperature,
        max_tokens: maxTokens,
        ...(jsonMode ? { response_format: { type: 'json_object' } } : {}),
        ...(tools ? { tools, tool_choice: 'auto' } : {}),
      }),
      signal: AbortSignal.timeout(60_000),
    });
  } catch (error: any) {
    if (userId) await settleQuota(userId, reserved, 0);
    throw error;
  }

  const latencyMs = Date.now() - startedAt;
  const bodyText = await response.text();

  if (!response.ok) {
    await trackAiUsage({
      userId: userId || 'anonymous',
      feature,
      model: target.model,
      endpoint: target.provider,
      promptTokens: 0,
      completionTokens: 0,
      latencyMs,
      status: 'error',
      error: bodyText.slice(0, 500),
    });
    if (userId) await settleQuota(userId, reserved, 0);
    const error = new Error(`${target.provider === 'azure' ? 'Azure OpenAI' : 'Groq'} API error (${response.status}): ${bodyText.slice(0, 300)}`);
    (error as any).statusCode = 502;
    throw error;
  }

  let data: GroqSuccess;
  try {
    data = JSON.parse(bodyText);
  } catch {
    if (userId) await settleQuota(userId, reserved, 0);
    const error = new Error('Groq returned an unparseable response');
    (error as any).statusCode = 502;
    throw error;
  }

  const usage = data.usage || { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

  await trackAiUsage({
    userId: userId || 'anonymous',
    feature,
    model: effectiveModel,
    endpoint: target.provider,
    promptTokens: usage.prompt_tokens,
    completionTokens: usage.completion_tokens,
    latencyMs,
  });

  if (userId) {
    await settleQuota(userId, reserved, usage.prompt_tokens + usage.completion_tokens);
  }

  return data;
}

export interface StreamResult {
  /** Raw fetch Response from Groq — the caller pipes its body to the client. */
  response: Response;
  /** Tokens reserved against the user's daily quota; caller settles after. */
  reservedTokens: number;
}

/**
 * Raw streamed call for tutor-stream. SSE passthrough happens in the route.
 * Reserves the estimated budget atomically before hitting Groq; the caller
 * settles with the real usage once the stream ends (see settleQuota).
 */
export async function groqStream(options: ChatOptions): Promise<StreamResult> {
  const target = chatTarget();
  if (!target.key) {
    const error = new Error(
      target.provider === 'azure' ? 'AZURE_OPENAI_API_KEY is not configured' : 'GROQ_API_KEY is not configured',
    );
    (error as any).statusCode = 503;
    throw error;
  }

  const maxTokens = options.maxTokens ?? 2048;
  let reserved = 0;
  if (options.userId) {
    const reservation = await reserveQuota(options.userId, maxTokens);
    reserved = reservation.reservedTokens;
    if (!reservation.allowed) {
      const error = new Error(
        `AI token budget exhausted (${reservation.remainingTokens} tokens left — refills continuously).`,
      );
      (error as any).statusCode = 429;
      (error as any).quota = reservation;
      throw error;
    }
  }

  const response = await fetch(target.url, {
    method: 'POST',
    headers: { ...target.headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: target.model,
      messages: options.messages,
      temperature: options.temperature ?? aiConfig.defaultTemperature,
      max_tokens: maxTokens,
      stream: true,
      stream_options: { include_usage: true },
    }),
    // Generous ceiling for a full streamed generation — still bounded, so a
    // provider that stalls mid-stream can't hold the connection forever.
    signal: AbortSignal.timeout(120_000),
  });

  if (!response.ok) {
    if (options.userId) await settleQuota(options.userId, reserved, 0);
  }

  return { response, reservedTokens: reserved };
}

/** Wolfram Alpha LLM API — raw text answer for math problems. */
export async function wolframQuery(question: string): Promise<string> {
  const appId = env.WOLFRAM_APP_ID;
  if (!appId) return 'Wolfram Alpha is not configured on this server.';

  try {
    const url = `https://www.wolframalpha.com/api/v1/llm-api?appid=${encodeURIComponent(appId)}&input=${encodeURIComponent(question)}`;
    const response = await fetch(url);
    if (!response.ok) {
      console.warn(`Wolfram Alpha failed with status ${response.status}`);
      return 'Wolfram Alpha could not solve this problem directly.';
    }
    return await response.text();
  } catch (error) {
    console.warn('Wolfram Alpha error:', error);
    return 'Wolfram Alpha could not solve this problem directly.';
  }
}

/** Usage summary for /api/ai/usage — "kya aa raha hai, kya nahi". */
export async function getUsageSummary(userId: string) {
  const now = new Date();
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);
  const startOfWeek = new Date(now);
  startOfWeek.setDate(now.getDate() - now.getDay());
  startOfWeek.setHours(0, 0, 0, 0);
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const [today, week, month, byFeature, recentErrors, quota] = await Promise.all([
    prisma.aiUsageLog.aggregate({
      where: { userId, createdAt: { gte: startOfDay } },
      _sum: { totalTokens: true, promptTokens: true, completionTokens: true },
      _count: { _all: true },
    }),
    prisma.aiUsageLog.aggregate({
      where: { userId, createdAt: { gte: startOfWeek } },
      _sum: { totalTokens: true },
      _count: { _all: true },
    }),
    prisma.aiUsageLog.aggregate({
      where: { userId, createdAt: { gte: startOfMonth } },
      _sum: { totalTokens: true },
      _count: { _all: true },
    }),
    prisma.aiUsageLog.groupBy({
      by: ['feature'],
      where: { userId, createdAt: { gte: startOfMonth } },
      _sum: { totalTokens: true, promptTokens: true, completionTokens: true },
      _count: { _all: true },
    }),
    prisma.aiUsageLog.findMany({
      where: { userId, status: 'error' },
      orderBy: { createdAt: 'desc' },
      take: 10,
      select: { feature: true, error: true, createdAt: true, totalTokens: true },
    }),
    getAiQuota(userId),
  ]);

  return {
    today: {
      requests: today._count._all,
      totalTokens: today._sum.totalTokens || 0,
      promptTokens: today._sum.promptTokens || 0,
      completionTokens: today._sum.completionTokens || 0,
    },
    week: { requests: week._count._all, totalTokens: week._sum.totalTokens || 0 },
    month: { requests: month._count._all, totalTokens: month._sum.totalTokens || 0 },
    byFeature: byFeature.map((f) => ({
      feature: f.feature,
      requests: f._count._all,
      totalTokens: f._sum.totalTokens || 0,
      promptTokens: f._sum.promptTokens || 0,
      completionTokens: f._sum.completionTokens || 0,
    })),
    recentErrors: recentErrors.map((e) => ({
      feature: e.feature,
      error: e.error?.slice(0, 200) || 'Unknown error',
      at: e.createdAt,
    })),
    quota: {
      limit: quota.quota,
      usedToday: quota.usedTokens,
      remainingToday: quota.remainingTokens,
      usedRequestsToday: quota.usedRequests,
    },
  };
}
