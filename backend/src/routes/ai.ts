import { Router, Request, Response } from 'express';
import { spawn } from 'child_process';
import path from 'path';

const router = Router();

router.post('/chat', async (req: Request, res: Response): Promise<void> => {
  const { messages, model, max_tokens, temperature } = req.body;
  
  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) throw new Error('GROQ_API_KEY is not configured');

    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: model || 'llama3-8b-8192',
        messages: messages || [],
        temperature: temperature || 0.7,
        max_tokens: max_tokens || 2048,
      })
    });

    if (!groqResponse.ok) {
      const errText = await groqResponse.text();
      console.error('Groq Chat Error:', errText);
      res.status(groqResponse.status).json({ error: 'AI Error', details: errText });
      return;
    }

    const data: any = await groqResponse.json();
    res.json(data);
  } catch (error: any) {
    console.error('Chat Error:', error);
    res.status(500).json({ error: 'Failed to process chat' });
  }
});

router.post('/solve-math', async (req: Request, res: Response): Promise<void> => {
  const { question } = req.body;
  if (!question) {
    res.status(400).json({ error: 'Question is required' });
    return;
  }

  try {
    // Step 1: Call Wolfram Alpha LLM API
    const wolframAppId = process.env.WOLFRAM_APP_ID;
    if (!wolframAppId) throw new Error('WOLFRAM_APP_ID is not configured');

    const wolframUrl = `https://www.wolframalpha.com/api/v1/llm-api?appid=${wolframAppId}&input=${encodeURIComponent(question)}`;
    const wolframResponse = await fetch(wolframUrl);
    
    let wolframText = '';
    if (wolframResponse.ok) {
      wolframText = await wolframResponse.text();
    } else {
      console.warn(`Wolfram Alpha failed with status ${wolframResponse.status}`);
      wolframText = 'Wolfram Alpha could not solve this problem directly.';
    }

    // Step 2: Call Groq API to format and explain
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) throw new Error('GROQ_API_KEY is not configured');

    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama3-8b-8192',
        messages: [
          {
            role: 'system',
            content: 'You are an expert Math Tutor. Given this math problem and the step-by-step solution from Wolfram Alpha, explain it simply to a student using clean Markdown and LaTeX math blocks. Be encouraging and concise.'
          },
          {
            role: 'user',
            content: `Problem: ${question}\n\nWolfram Output: ${wolframText}`
          }
        ],
        temperature: 0.7,
        max_tokens: 1024
      })
    });

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text();
      console.error('Groq Error:', errorText);
      throw new Error('Failed to get response from Groq');
    }

    const groqData: any = await groqResponse.json();
    const explanation = groqData.choices[0].message.content;

    res.json({ reply: explanation });
  } catch (error: any) {
    console.error('Math Solver Error:', error);
    res.status(500).json({ error: 'Failed to solve math problem', details: error.message });
  }
});

router.post('/tutor-stream', async (req: Request, res: Response): Promise<void> => {
  const { message } = req.body;
  if (!message) {
    res.status(400).json({ error: 'Message is required' });
    return;
  }

  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) throw new Error('GROQ_API_KEY is not configured');

    const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama3-8b-8192',
        messages: [
          {
            role: 'system',
            content: 'You are Nexus, a friendly AI Tutor for Indian students. ALWAYS respond in clear English. Be helpful, encouraging, and concise. Use simple language. Format responses properly.'
          },
          {
            role: 'user',
            content: message
          }
        ],
        temperature: 0.7,
        max_tokens: 2048,
        stream: true
      })
    });

    if (!groqResponse.ok || !groqResponse.body) {
      throw new Error(`Groq API error: ${groqResponse.status}`);
    }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    });

    const bodyStream = groqResponse.body as any;
    if (typeof bodyStream.pipe === 'function') {
      // If node-fetch is used
      bodyStream.pipe(res);
    } else {
      // If native fetch Web Streams are used
      const reader = bodyStream.getReader();
      const decoder = new TextDecoder('utf-8');
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value, { stream: true });
        res.write(chunk);
      }
      res.end();
    }
  } catch (error: any) {
    console.error('Tutor Stream Error:', error);
    res.status(500).end();
  }
});

export default router;
