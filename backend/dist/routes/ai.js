"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const child_process_1 = require("child_process");
const path_1 = __importDefault(require("path"));
const router = (0, express_1.Router)();
router.post('/chat', (req, res) => {
    const { message, userId, context } = req.body;
    // Example of calling the python AI agents
    // In a real production app, we would use a message queue or gRPC
    const pythonProcess = (0, child_process_1.spawn)('python', [
        path_1.default.join(__dirname, '../../../main.py'), // Path to main.py
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
            }
            catch (e) {
                res.json({ reply: resultData.trim() });
            }
        }
        else {
            res.status(500).json({ error: 'AI processing failed' });
        }
    });
});
router.post('/solve-math', async (req, res) => {
    const { question } = req.body;
    if (!question) {
        res.status(400).json({ error: 'Question is required' });
        return;
    }
    try {
        // Step 1: Call Wolfram Alpha LLM API
        const wolframAppId = process.env.WOLFRAM_APP_ID;
        if (!wolframAppId)
            throw new Error('WOLFRAM_APP_ID is not configured');
        const wolframUrl = `https://www.wolframalpha.com/api/v1/llm-api?appid=${wolframAppId}&input=${encodeURIComponent(question)}`;
        const wolframResponse = await fetch(wolframUrl);
        let wolframText = '';
        if (wolframResponse.ok) {
            wolframText = await wolframResponse.text();
        }
        else {
            console.warn(`Wolfram Alpha failed with status ${wolframResponse.status}`);
            wolframText = 'Wolfram Alpha could not solve this problem directly.';
        }
        // Step 2: Call Groq API to format and explain
        const groqApiKey = process.env.GROQ_API_KEY;
        if (!groqApiKey)
            throw new Error('GROQ_API_KEY is not configured');
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
        const groqData = await groqResponse.json();
        const explanation = groqData.choices[0].message.content;
        res.json({ reply: explanation });
    }
    catch (error) {
        console.error('Math Solver Error:', error);
        res.status(500).json({ error: 'Failed to solve math problem', details: error.message });
    }
});
router.post('/tutor-stream', async (req, res) => {
    const { message } = req.body;
    if (!message) {
        res.status(400).json({ error: 'Message is required' });
        return;
    }
    try {
        const groqApiKey = process.env.GROQ_API_KEY;
        if (!groqApiKey)
            throw new Error('GROQ_API_KEY is not configured');
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
        const bodyStream = groqResponse.body;
        if (typeof bodyStream.pipe === 'function') {
            // If node-fetch is used
            bodyStream.pipe(res);
        }
        else {
            // If native fetch Web Streams are used
            const reader = bodyStream.getReader();
            const decoder = new TextDecoder('utf-8');
            while (true) {
                const { done, value } = await reader.read();
                if (done)
                    break;
                const chunk = decoder.decode(value, { stream: true });
                res.write(chunk);
            }
            res.end();
        }
    }
    catch (error) {
        console.error('Tutor Stream Error:', error);
        res.status(500).end();
    }
});
exports.default = router;
