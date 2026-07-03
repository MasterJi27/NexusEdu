"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const client_1 = require("@prisma/client");
const router = (0, express_1.Router)();
const prisma = new client_1.PrismaClient();
// Get assignments for a module
router.get('/module/:moduleId', async (req, res) => {
    try {
        const assignments = await prisma.assignment.findMany({
            where: { moduleId: req.params.moduleId }
        });
        res.json(assignments);
    }
    catch (error) {
        res.status(500).json({ error: 'Failed to fetch assignments' });
    }
});
// Submit an assignment
router.post('/submit', async (req, res) => {
    try {
        const { assignmentId, studentId, content, fileUrl } = req.body;
        const submission = await prisma.submission.create({
            data: {
                assignmentId,
                studentId,
                content,
                fileUrl
            }
        });
        res.status(201).json(submission);
    }
    catch (error) {
        res.status(500).json({ error: 'Failed to submit assignment' });
    }
});
exports.default = router;
//# sourceMappingURL=assignments.js.map