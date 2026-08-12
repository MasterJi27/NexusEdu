import { env } from '../lib/env';

/**
 * Prompt-injection / jailbreak guard. Uses the tiny free prompt-guard model
 * on the same provider as the chat models — a single cheap call classifies a
 * user message as benign or an injection attempt before it ever reaches the
 * main model. Fail-open: if the guard is unavailable the request proceeds
 * (the client-side sanitizer in the app is the second layer).
 */

const PROMPT_GUARD_MODEL = 'meta-llama/llama-prompt-guard-2-86m';

export interface ModerationResult {
  flagged: boolean;
  label: string;
}

export async function checkPromptInjection(text: string): Promise<ModerationResult> {
  if (!env.GROQ_API_KEY || !text) return { flagged: false, label: 'unknown' };
  try {
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: PROMPT_GUARD_MODEL,
        messages: [{ role: 'user', content: text }],
        max_tokens: 8,
      }),
    });
    if (!response.ok) return { flagged: false, label: 'unknown' };
    const data = await response.json();
    const content = (data?.choices?.[0]?.message?.content || '').toLowerCase().trim();
    // The guard returns the injection probability (e.g. "0.9996") — flag
    // anything clearly above 0.5. Some deployments emit text labels instead;
    // handle both.
    const probability = parseFloat(content);
    const flagged = !Number.isNaN(probability)
      ? probability > 0.5
      : content.includes('injection');
    return { flagged, label: content || 'unknown' };
  } catch (error) {
    console.error('Prompt guard error:', error);
    return { flagged: false, label: 'unknown' };
  }
}
