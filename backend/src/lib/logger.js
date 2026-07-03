"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logLogin = exports.logActivity = void 0;
const client_1 = require("@prisma/client");
const express_1 = require("express");
const prisma = new client_1.PrismaClient();
const logActivity = async (userId, action, metadata) => {
    try {
        await prisma.activityLog.create({
            data: {
                userId,
                action,
                metadata: metadata || {}
            }
        });
    }
    catch (error) {
        console.error('Failed to log activity:', error);
    }
};
exports.logActivity = logActivity;
const logLogin = async (req, userId) => {
    try {
        const ipAddress = req.ip || req.connection.remoteAddress || 'unknown';
        const deviceInfo = req.headers['user-agent'] || 'unknown';
        await prisma.loginLog.create({
            data: {
                userId,
                ipAddress,
                deviceInfo
            }
        });
        // Also update lastLoginAt on User
        await prisma.user.update({
            where: { id: userId },
            data: { lastLoginAt: new Date() }
        });
    }
    catch (error) {
        console.error('Failed to log login:', error);
    }
};
exports.logLogin = logLogin;
//# sourceMappingURL=logger.js.map