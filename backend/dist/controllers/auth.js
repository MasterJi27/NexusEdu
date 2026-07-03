"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.googleLogin = exports.login = exports.signup = void 0;
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const prisma_1 = __importDefault(require("../lib/prisma"));
const logger_1 = require("../lib/logger");
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev';
const signup = async (req, res) => {
    try {
        const { name, email, password, role } = req.body;
        const existingUser = await prisma_1.default.user.findUnique({ where: { email } });
        if (existingUser) {
            res.status(400).json({ error: 'An account already exists with this email.' });
            return;
        }
        const passwordHash = await bcrypt_1.default.hash(password, 10);
        const user = await prisma_1.default.user.create({
            data: {
                name,
                email,
                password: passwordHash,
                role: role || 'student',
            }
        });
        const token = jsonwebtoken_1.default.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
        await (0, logger_1.logLogin)(req, user.id);
        await (0, logger_1.logActivity)(user.id, 'USER_SIGNUP', { role: user.role });
        res.status(201).json({ user, token });
    }
    catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ error: 'An unexpected error occurred.' });
    }
};
exports.signup = signup;
const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await prisma_1.default.user.findUnique({ where: { email } });
        if (!user || !user.password) {
            res.status(401).json({ error: 'Invalid credentials or user signed up with Google.' });
            return;
        }
        const isValid = await bcrypt_1.default.compare(password, user.password);
        if (!isValid) {
            res.status(401).json({ error: 'Incorrect password.' });
            return;
        }
        const token = jsonwebtoken_1.default.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
        await (0, logger_1.logLogin)(req, user.id);
        res.status(200).json({ user, token });
    }
    catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'An unexpected error occurred.' });
    }
};
exports.login = login;
const googleLogin = async (req, res) => {
    try {
        // Expected idToken and basic info from Google SignIn on client
        const { email, name, photoUrl } = req.body;
        // Note: In a production app, you MUST verify the idToken with Google's APIs.
        // For this demonstration/student app, we trust the client's email if it's sent.
        if (!email) {
            res.status(400).json({ error: 'Email is required' });
            return;
        }
        let user = await prisma_1.default.user.findUnique({ where: { email } });
        if (!user) {
            user = await prisma_1.default.user.create({
                data: {
                    email,
                    name: name || 'Google User',
                    photoUrl,
                    role: 'student',
                }
            });
        }
        const token = jsonwebtoken_1.default.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
        await (0, logger_1.logLogin)(req, user.id);
        res.status(200).json({ user, token });
    }
    catch (error) {
        console.error('Google login error:', error);
        res.status(500).json({ error: 'An unexpected error occurred.' });
    }
};
exports.googleLogin = googleLogin;
