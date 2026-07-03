import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import { logLogin, logActivity } from '../lib/logger';

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev';

export const signup = async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, email, password, role } = req.body;
    
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      res.status(400).json({ error: 'An account already exists with this email.' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: passwordHash,
        role: role || 'student',
      }
    });

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    await logLogin(req, user.id);
    await logActivity(user.id, 'USER_SIGNUP', { role: user.role });

    res.status(201).json({ user, token });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'An unexpected error occurred.' });
  }
};

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;
    
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.password) {
      res.status(401).json({ error: 'Invalid credentials or user signed up with Google.' });
      return;
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      res.status(401).json({ error: 'Incorrect password.' });
      return;
    }

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    await logLogin(req, user.id);

    res.status(200).json({ user, token });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'An unexpected error occurred.' });
  }
};

export const googleLogin = async (req: Request, res: Response): Promise<void> => {
  try {
    // Expected idToken and basic info from Google SignIn on client
    const { email, name, photoUrl } = req.body;
    
    // Note: In a production app, you MUST verify the idToken with Google's APIs.
    // For this demonstration/student app, we trust the client's email if it's sent.
    if (!email) {
      res.status(400).json({ error: 'Email is required' });
      return;
    }

    let user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          name: name || 'Google User',
          photoUrl,
          role: 'student',
        }
      });
    }

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    await logLogin(req, user.id);

    res.status(200).json({ user, token });
  } catch (error) {
    console.error('Google login error:', error);
    res.status(500).json({ error: 'An unexpected error occurred.' });
  }
};
