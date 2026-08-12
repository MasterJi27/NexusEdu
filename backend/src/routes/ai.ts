import { Router } from 'express';
import { z } from 'zod';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { validateBody } from '../middlewares/validate';
import {
  aiConfig,
  systemPrompts,
  groqChat,
  groqStream,
  wolframQuery,
  trackAiUsage,
  getUsageSummary,
  getAiQuota,
  settleQuota,
  consumeAiRequest,
} from '../services/aiService';
import { retrieve, buildRagContext } from '../services/ragService';
import { checkPromptInjection } from '../services/moderationService';
import { agentTools, runTool } from '../services/agentTools';

const router = Router();

/**
 * Per-request AI rate control. Drains a continuous-refill request bucket
 * (capacity 30, ~1 refill per 15 s) instead of a fixed window, so a burst
 * can never line up with a window edge to get a free refill. The token
 * budget itself (consumeAiRequest's sibling bucket) is the business control.
 */
router.use(authenticate, async (req: AuthRequest, res, next) => {
  try {
    const result = await consumeAiRequest(req.user!.id);
    if (!result.allowed) {
      res.status(429).json({
        error:
          'Too many AI requests. Tokens refill continuously â€” try again in a moment.',
        retryAfterSeconds: result.retryAfterSeconds,
      });
      return;
    }
    next();
  } catch (error) {
    // Quota must never break the API: fail open with a log.
    console.error('AI request bucket check failed:', error);
    next();
  }
});

const chatSchema = z.object({
  messages: z.array(z.object({
    role: z.enum(['system', 'user', 'assistant']),
    content: z.string().max(8000),
  })).min(1).max(50),
  temperature: z.number().min(0).max(2).optional(),
  max_tokens: z.number().int().positive().max(4096).optional(),
});

router.post('/chat', validateBody(chatSchema), async (req: AuthRequest, res) => {
  const { messages, temperature, max_tokens } = req.body;

  try {
    const lastUserMessage = [...messages].reverse().find((m: any) => m.role === 'user')?.content;

    // Prompt-injection guard before anything reaches the model.
    if (lastUserMessage) {
      const moderation = await checkPromptInjection(lastUserMessage);
      if (moderation.flagged) {
        res.status(400).json({ error: 'Your message was flagged for safety. Please rephrase.' });
        return;
      }
    }

    const hasSystemPrompt = messages.some((m: any) => m.role === 'system');

    let systemContent = hasSystemPrompt
      ? messages.find((m: any) => m.role === 'system')!.content
      : systemPrompts.general;

    // RAG: ground the answer in the student's own course material.
    if (lastUserMessage) {
      const chunks = await retrieve(req.user!.id, lastUserMessage, 5);
      const ragContext = buildRagContext(chunks);
      if (ragContext) {
        systemContent = `${systemContent}\n\n${ragContext}`;
      }
    }

    const enrichedMessages = hasSystemPrompt
      ? messages.map((m: any) =>
          m.role === 'system' ? { ...m, content: systemContent } : m,
        )
      : [{ role: 'system', content: systemContent }, ...messages];

    const data = await groqChat({
      messages: enrichedMessages,
      temperature,
      maxTokens: max_tokens,
      feature: 'general',
      userId: req.user!.id,
    });

    const quota = await getAiQuota(req.user!.id);
    res.json({
      ...data,
      usage: {
        prompt_tokens: data.usage?.prompt_tokens || 0,
        completion_tokens: data.usage?.completion_tokens || 0,
        total_tokens: data.usage?.total_tokens || 0,
        remaining_today: quota.remainingTokens,
      },
    });
  } catch (error: any) {
    const status = error.statusCode || 500;
    res.status(status).json({
      error: status === 429 ? 'AI token budget exhausted - tokens refill continuously' : 'AI request failed',
      details: error.message,
      ...(error.quota ? { quota: error.quota } : {}),
    });
  }
});

const solveMathSchema = z.object({
  question: z.string().trim().min(1).max(2000),
});

router.post('/solve-math', validateBody(solveMathSchema), async (req: AuthRequest, res) => {
  const { question } = req.body;
  const userId = req.user!.id;
  const startedAt = Date.now();

  try {
    const quota = await getAiQuota(userId);
    if (!quota.allowed) {
      res.status(429).json({
        error: 'AI token budget exhausted - tokens refill continuously',
        quota,
      });
      return;
    }

    const wolframText = await wolframQuery(question);

    const data = await groqChat({
      messages: [
        { role: 'system', content: systemPrompts.math },
        { role: 'user', content: `Problem: ${question}\n\nWolfram Output: ${wolframText}` },
      ],
      temperature: 0.3,
      maxTokens: 1024,
      feature: 'math',
      userId,
    });

    const reply = data.choices[0]?.message?.content || '';
    const usage = data.usage || { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

    await trackAiUsage({
      userId,
      feature: 'solve-math',
      model: aiConfig.model,
      endpoint: 'wolfram',
      promptTokens: usage.prompt_tokens,
      completionTokens: usage.completion_tokens,
      latencyMs: Date.now() - startedAt,
    });

    const quotaAfter = await getAiQuota(userId);
    res.json({
      reply,
      usage: {
        prompt_tokens: usage.prompt_tokens,
        completion_tokens: usage.completion_tokens,
        total_tokens: usage.total_tokens,
        remaining_today: quotaAfter.remainingTokens,
      },
    });
  } catch (error: any) {
    console.error('Math solver error:', error);
    res.status(error.statusCode || 500).json({
      error: 'Failed to solve math problem',
      details: error.message,
      ...(error.quota ? { quota: error.quota } : {}),
    });
  }
});

const tutorStreamSchema = z.object({
  message: z.string().trim().min(1).max(4000),
});

router.post('/tutor-stream', validateBody(tutorStreamSchema), async (req: AuthRequest, res) => {
  const { message } = req.body;
  const userId = req.user!.id;
  const startedAt = Date.now();
  let reservedTokens = 0;

  try {
    // Prompt-injection guard before anything reaches the model.
    const moderation = await checkPromptInjection(message);
    if (moderation.flagged) {
      res.status(400).json({ error: 'Your message was flagged for safety. Please rephrase.' });
      return;
    }

    // Early 429 without burning a Groq call; groqStream then reserves
    // atomically as the real enforcement.
    const quota = await getAiQuota(userId);
    if (!quota.allowed) {
      res.status(429).json({ error: 'AI token budget exhausted - tokens refill continuously', quota });
      return;
    }

    // RAG: retrieve relevant course material and append it to the tutor prompt.
    let tutorPrompt = systemPrompts.tutor;
    const chunks = await retrieve(req.user!.id, message, 5);
    const ragContext = buildRagContext(chunks);
    if (ragContext) {
      tutorPrompt = `${tutorPrompt}\n\n${ragContext}`;
    }

    const streamResult = await groqStream({
      messages: [
        { role: 'system', content: tutorPrompt },
        { role: 'user', content: message },
      ],
      feature: 'tutor-stream',
      userId,
    });
    const { response: groqResponse, reservedTokens: reserved } = streamResult;
    reservedTokens = reserved;

    if (!groqResponse.ok || !groqResponse.body) {
      const errText = await groqResponse.text();
      throw new Error(`Groq API error: ${groqResponse.status} ${errText.slice(0, 300)}`);
    }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    const bodyStream = groqResponse.body as any;
    let usage: any = null;

    if (typeof bodyStream.pipe === 'function' && typeof bodyStream.pipeTo !== 'function') {
      bodyStream.pipe(res);
      await new Promise((resolve) => bodyStream.on('end', resolve));
    } else {
      const reader = bodyStream.getReader();
      const decoder = new TextDecoder('utf-8');
      let buffer = '';
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const match = buffer.match(/"usage":\s*(\{[^}]*\})/);
        if (match) {
          try { usage = JSON.parse(match[1]); } catch { /* ignore malformed usage chunk */ }
        }
        res.write(value);
      }
      res.end();
    }

    const usageRecord = usage || { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };
    await trackAiUsage({
      userId,
      feature: 'tutor-stream',
      model: aiConfig.model,
      endpoint: 'groq',
      promptTokens: usageRecord.prompt_tokens || 0,
      completionTokens: usageRecord.completion_tokens || 0,
      latencyMs: Date.now() - startedAt,
    });
    await settleQuota(
      userId,
      reservedTokens,
      (usageRecord.prompt_tokens || 0) + (usageRecord.completion_tokens || 0),
    );
  } catch (error: any) {
    console.error('Tutor stream error:', error);
    // A dead stream should not poison the user's quota for the rest of the
    // day â€” refund the reservation; the partial tokens genuinely consumed
    // are unmeasurable and tiny by comparison.
    await settleQuota(userId, reservedTokens, 0).catch(() => {});
    if (!res.headersSent) {
      res.status(error.statusCode || 500).json({ error: 'Failed to stream tutor response', details: error.message });
      return;
    }
    res.write(`data: {"error": ${JSON.stringify(error.message)}}\n\n`);
    res.end();
  }
});

const agentMessageSchema = z.object({
  role: z.enum(['system', 'user', 'assistant', 'tool']),
  content: z.string().max(4000),
  tool_call_id: z.string().optional(),
  name: z.string().optional(),
});

const agentSchema = z.object({
  messages: z.array(agentMessageSchema).min(1).max(20),
});

/**
 * Data agent: the model can call tools to answer from the student's real
 * data (profile, attendance, AI usage, assignments, notes). A short tool
 * loop (max 3 rounds) keeps latency and token spend bounded.
 */
router.post('/agent', validateBody(agentSchema), async (req: AuthRequest, res) => {
  const { messages } = req.body;
  const userId = req.user!.id;

  try {
    const lastUserMessage = [...messages].reverse().find((m: any) => m.role === 'user')?.content;

    const moderation = await checkPromptInjection(lastUserMessage || '');
    if (moderation.flagged) {
      res.status(400).json({ error: 'Your message was flagged for safety. Please rephrase.' });
      return;
    }

    // RAG: ground answers in the student's course material as well.
    const chunks = await retrieve(userId, lastUserMessage || '', 4);
    const ragContext = buildRagContext(chunks);

    const systemPrompt =
      'You are Nexus, an AI study assistant for Indian students (CBSE, ICSE, JEE, NEET). ' +
      'You can call tools to answer from the student\'s real data â€” profile, attendance, ' +
      'AI usage, assignments and teacher notes. ALWAYS prefer tool results over guesses; ' +
      'if a tool returns an error, say you could not fetch that data. ' +
      'Be encouraging, concise, and use simple English. ' +
      (ragContext ? `\n\n${ragContext}` : '');

    const working: any[] = [
      { role: 'system', content: systemPrompt },
      ...messages,
    ];

    let data = await groqChat({
      messages: working,
      feature: 'agent',
      userId,
      maxTokens: 1500,
      tools: agentTools,
    });

    for (let round = 0; round < 3; round += 1) {
      const toolCalls = data.choices?.[0]?.message?.tool_calls;
      if (!toolCalls || toolCalls.length === 0) break;

      working.push({
        role: 'assistant',
        content: data.choices[0].message.content ?? '',
        tool_calls: toolCalls,
      });
      for (const call of toolCalls) {
        const result = await runTool(call.function.name, call.function.arguments, userId);
        working.push({
          role: 'tool',
          tool_call_id: call.id,
          name: call.function.name,
          content: result,
        });
      }
      data = await groqChat({
        messages: working,
        feature: 'agent',
        userId,
        maxTokens: 1500,
        tools: agentTools,
      });
    }

    const quota = await getAiQuota(userId);
    res.json({
      choices: data.choices,
      usage: {
        prompt_tokens: data.usage?.prompt_tokens || 0,
        completion_tokens: data.usage?.completion_tokens || 0,
        total_tokens: data.usage?.total_tokens || 0,
        remaining_today: quota.remainingTokens,
      },
    });
  } catch (error: any) {
    console.error('Agent error:', error);
    res.status(error.statusCode || 500).json({
      error: 'AI request failed',
      details: error.message,
      ...(error.quota ? { quota: error.quota } : {}),
    });
  }
});

router.get('/usage', async (req: AuthRequest, res) => {
  try {
    const summary = await getUsageSummary(req.user!.id);
    res.json(summary);
  } catch (error) {
    console.error('Usage summary error:', error);
    res.status(500).json({ error: 'Failed to load AI usage' });
  }
});

export default router;
