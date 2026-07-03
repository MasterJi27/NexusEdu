import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import coursesRoutes from './routes/courses';
import assignmentsRoutes from './routes/assignments';
import aiRoutes from './routes/ai';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/courses', coursesRoutes);
app.use('/api/assignments', assignmentsRoutes);
app.use('/api/ai', aiRoutes);

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Nexus Edu Backend is running' });
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
