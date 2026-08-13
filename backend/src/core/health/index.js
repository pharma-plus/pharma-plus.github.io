import { Router } from 'express';
import { pool } from '../../db/pool.js';
import { config } from '../../config/index.js';

const router = Router();

router.get('/', async (_req, res) => {
  const health = {
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    version: '2.0.0',
  };
  try {
    await pool.query('SELECT 1');
    health.database = 'connected';
  } catch {
    health.status = 'degraded';
    health.database = 'disconnected';
  }
  return res.status(health.status === 'ok' ? 200 : 503).json(health);
});

export const healthRouter = router;
