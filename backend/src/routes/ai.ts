import { Router, Request, Response } from 'express';
import { spawn } from 'child_process';
import path from 'path';

const router = Router();

router.post('/chat', (req: Request, res: Response) => {
  const { message, userId, context } = req.body;
  
  // Example of calling the python AI agents
  // In a real production app, we would use a message queue or gRPC
  const pythonProcess = spawn('python', [
    path.join(__dirname, '../../../main.py'), // Path to main.py
    'chat',
    JSON.stringify({ message, userId, context })
  ]);

  let resultData = '';
  
  pythonProcess.stdout.on('data', (data) => {
    resultData += data.toString();
  });

  pythonProcess.stderr.on('data', (data) => {
    console.error(`AI Error: ${data}`);
  });

  pythonProcess.on('close', (code) => {
    if (code === 0) {
      try {
        // Assume the python script returns JSON
        const jsonResponse = JSON.parse(resultData);
        res.json(jsonResponse);
      } catch (e) {
        res.json({ reply: resultData.trim() });
      }
    } else {
      res.status(500).json({ error: 'AI processing failed' });
    }
  });
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

export default router;
