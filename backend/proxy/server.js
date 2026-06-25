require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const morgan = require('morgan');
const { body, validationResult } = require('express-validator');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

// In-memory user store (use database in production)
const users = new Map();
const refreshTokens = new Set();
const requestLogs = [];

// Initialize admin user
(async () => {
  const adminHash = await bcrypt.hash(process.env.ADMIN_PASSWORD, 12);
  users.set(process.env.ADMIN_EMAIL, {
    id: uuidv4(),
    email: process.env.ADMIN_EMAIL,
    password: adminHash,
    name: 'Admin',
    role: 'admin',
    createdAt: new Date(),
    requestCount: 0,
    lastActive: null,
  });
})();

// Middleware
app.use(helmet());
app.use(cors({
  origin: ['http://localhost:3000', 'https://nexusedu.app'],
  credentials: true,
}));
app.use(express.json({ limit: '10kb' }));
app.use(morgan('combined'));

// Global Rate Limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(globalLimiter);

// AI Endpoint Rate Limiter (stricter)
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'AI request limit reached. Wait 1 minute.' },
  keyGenerator: (req) => req.user?.id || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
});

// Auth Rate Limiter
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { error: 'Too many auth attempts. Try again in 15 minutes.' },
});

// Input Sanitization Middleware
const sanitizeInput = (req, res, next) => {
  if (req.body.prompt) {
    const blocked = [
      'ignore previous instructions',
      'ignore all instructions',
      'ignore above instructions',
      'ignore the above',
      'ignore your instructions',
      'disregard previous',
      'forget everything',
      'you are now',
      'act as if',
      'pretend you are',
      'new instructions:',
      'system prompt:',
      'reveal system prompt',
      'override safety',
      'bypass filters',
      'jailbreak',
      'developer mode',
    ];

    const lower = req.body.prompt.toLowerCase();
    for (const pattern of blocked) {
      if (lower.includes(pattern)) {
        return res.status(400).json({
          error: 'Message flagged for safety. Please rephrase.',
        });
      }
    }

    req.body.prompt = req.body.prompt.substring(0, 4000);
  }
  next();
};

// JWT Authentication Middleware
const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

// Optional Authentication (for guest access)
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      req.user = jwt.verify(token, process.env.JWT_SECRET);
    } catch {}
  }
  next();
};

// Request Logger
const logRequest = (req, res, next) => {
  const log = {
    id: uuidv4(),
    userId: req.user?.id || 'anonymous',
    ip: req.ip,
    method: req.method,
    path: req.path,
    timestamp: new Date(),
    userAgent: req.headers['user-agent'],
  };

  requestLogs.push(log);
  if (requestLogs.length > 10000) requestLogs.shift();

  next();
};

// Validation Rules
const signupValidation = [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 8 }).matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/),
  body('name').trim().isLength({ min: 2, max: 50 }),
];

const loginValidation = [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
];

const chatValidation = [
  body('prompt').trim().isLength({ min: 1, max: 4000 }),
  body('systemPrompt').optional().trim().isLength({ max: 1000 }),
];

// Generate Tokens
function generateTokens(user) {
  const accessToken = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '1h' }
  );

  const refreshToken = jwt.sign(
    { id: user.id, type: 'refresh' },
    process.env.JWT_SECRET,
    { expiresIn: '30d' }
  );

  refreshTokens.add(refreshToken);
  return { accessToken, refreshToken };
}

// OpenRouter API Call
async function callOpenRouter(messages, options = {}) {
  const response = await fetch(process.env.OPENROUTER_BASE_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'HTTP-Referer': 'https://nexusedu.app',
      'X-Title': 'NexusEdu',
    },
    body: JSON.stringify({
      model: options.model || process.env.OPENROUTER_MODEL,
      messages,
      max_tokens: options.maxTokens || 1024,
      temperature: options.temperature || 0.7,
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenRouter API error: ${response.status}`);
  }

  return response.json();
}

// ==================== ROUTES ====================

// Health Check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date(),
  });
});

// ==================== AUTH ROUTES ====================

// Signup
app.post('/api/auth/signup', authLimiter, signupValidation, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password, name } = req.body;

    if (users.has(email)) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const user = {
      id: uuidv4(),
      email,
      password: hashedPassword,
      name,
      role: 'user',
      createdAt: new Date(),
      requestCount: 0,
      lastActive: null,
    };

    users.set(email, user);
    const tokens = generateTokens(user);

    res.status(201).json({
      message: 'Account created successfully',
      user: { id: user.id, email: user.email, name: user.name },
      ...tokens,
    });
  } catch (error) {
    res.status(500).json({ error: 'Signup failed' });
  }
});

// Login
app.post('/api/auth/login', authLimiter, loginValidation, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;
    const user = users.get(email);

    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    user.lastActive = new Date();
    const tokens = generateTokens(user);

    res.json({
      message: 'Login successful',
      user: { id: user.id, email: user.email, name: user.name },
      ...tokens,
    });
  } catch (error) {
    res.status(500).json({ error: 'Login failed' });
  }
});

// Refresh Token
app.post('/api/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken || !refreshTokens.has(refreshToken)) {
    return res.status(401).json({ error: 'Invalid refresh token' });
  }

  try {
    const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET);
    const user = Array.from(users.values()).find(u => u.id === decoded.id);

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    refreshTokens.delete(refreshToken);
    const tokens = generateTokens(user);

    res.json(tokens);
  } catch (error) {
    refreshTokens.delete(refreshToken);
    res.status(401).json({ error: 'Token expired' });
  }
});

// Logout
app.post('/api/auth/logout', authenticate, (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) refreshTokens.delete(refreshToken);
  res.json({ message: 'Logged out' });
});

// ==================== AI ROUTES ====================

// Chat with AI
app.post('/api/ai/chat', authenticate, aiLimiter, sanitizeInput, logRequest, async (req, res) => {
  try {
    const { prompt, systemPrompt = '' } = req.body;
    const user = users.get(req.user.email);
    if (user) {
      user.requestCount++;
      user.lastActive = new Date();
    }

    const messages = [];
    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt });
    }
    messages.push({
      role: 'system',
      content: 'You are Nexus, a helpful AI tutor for Indian students. Always respond in clear English. Be concise and educational.',
    });
    messages.push({ role: 'user', content: prompt });

    const result = await callOpenRouter(messages);

    res.json({
      result: result.choices[0]?.message?.content || 'No response generated.',
      usage: result.usage,
    });
  } catch (error) {
    res.status(500).json({ error: 'AI service temporarily unavailable' });
  }
});

// Solve Doubt
app.post('/api/ai/solve-doubt', authenticate, aiLimiter, sanitizeInput, logRequest, async (req, res) => {
  try {
    const { question, subject = 'General' } = req.body;

    const messages = [
      {
        role: 'system',
        content: `You are a helpful ${subject} tutor. Explain step by step in simple English. Use examples.`,
      },
      { role: 'user', content: question },
    ];

    const result = await callOpenRouter(messages);
    res.json({ result: result.choices[0]?.message?.content });
  } catch (error) {
    res.status(500).json({ error: 'Failed to solve doubt' });
  }
});

// Generate Quiz
app.post('/api/ai/generate-quiz', authenticate, aiLimiter, sanitizeInput, logRequest, async (req, res) => {
  try {
    const { topic, subject = 'General', count = 5 } = req.body;

    const messages = [
      {
        role: 'system',
        content: 'Generate quiz questions with 4 options each. Mark the correct answer. Format clearly.',
      },
      {
        role: 'user',
        content: `Generate ${count} quiz questions on ${topic} in ${subject}.`,
      },
    ];

    const result = await callOpenRouter(messages);
    res.json({ result: result.choices[0]?.message?.content });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate quiz' });
  }
});

// Generate Notes
app.post('/api/ai/generate-notes', authenticate, aiLimiter, sanitizeInput, logRequest, async (req, res) => {
  try {
    const { topic, subject = 'General' } = req.body;

    const messages = [
      {
        role: 'system',
        content: 'Create comprehensive study notes with headings, bullet points, and key concepts.',
      },
      {
        role: 'user',
        content: `Generate study notes on ${topic} in ${subject}.`,
      },
    ];

    const result = await callOpenRouter(messages);
    res.json({ result: result.choices[0]?.message?.content });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate notes' });
  }
});

// Math Solver
app.post('/api/ai/solve-math', authenticate, aiLimiter, sanitizeInput, logRequest, async (req, res) => {
  try {
    const { problem } = req.body;

    const messages = [
      {
        role: 'system',
        content: 'Solve math problems step by step. Show all working clearly.',
      },
      { role: 'user', content: problem },
    ];

    const result = await callOpenRouter(messages);
    res.json({ result: result.choices[0]?.message?.content });
  } catch (error) {
    res.status(500).json({ error: 'Failed to solve math problem' });
  }
});

// ==================== USER ROUTES ====================

// Get Profile
app.get('/api/user/profile', authenticate, (req, res) => {
  const user = users.get(req.user.email);
  if (!user) return res.status(404).json({ error: 'User not found' });

  res.json({
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    requestCount: user.requestCount,
    lastActive: user.lastActive,
  });
});

// Update Profile
app.put('/api/user/profile', authenticate, async (req, res) => {
  const user = users.get(req.user.email);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const { name, currentPassword, newPassword } = req.body;

  if (newPassword) {
    if (!currentPassword || !(await bcrypt.compare(currentPassword, user.password))) {
      return res.status(400).json({ error: 'Current password incorrect' });
    }
    user.password = await bcrypt.hash(newPassword, 12);
  }

  if (name) user.name = name;

  res.json({ message: 'Profile updated', user: { id: user.id, email: user.email, name: user.name } });
});

// ==================== ADMIN ROUTES ====================

// Get Stats (admin only)
app.get('/api/admin/stats', authenticate, (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  res.json({
    totalUsers: users.size,
    totalRequests: requestLogs.length,
    activeUsers: Array.from(users.values()).filter(u => {
      const lastActive = u.lastActive;
      return lastActive && (Date.now() - new Date(lastActive).getTime()) < 86400000;
    }).length,
    recentRequests: requestLogs.slice(-50),
  });
});

// Get All Users (admin only)
app.get('/api/admin/users', authenticate, (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  const userList = Array.from(users.values()).map(u => ({
    id: u.id,
    email: u.email,
    name: u.name,
    role: u.role,
    requestCount: u.requestCount,
    lastActive: u.lastActive,
    createdAt: u.createdAt,
  }));

  res.json({ users: userList });
});

// ==================== ERROR HANDLING ====================

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start Server
app.listen(PORT, () => {
  console.log(`NexusEdu Proxy running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
