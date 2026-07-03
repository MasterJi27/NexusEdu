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

export default router;
