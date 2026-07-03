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
exports.default = router;
//# sourceMappingURL=ai.js.map