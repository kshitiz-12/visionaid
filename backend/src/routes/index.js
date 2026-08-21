const express = require('express');
const profileRoutes = require('./profileRoutes');
const { getPrisma } = require('../config/prisma');
const { getSupabaseAdmin } = require('../config/supabase');

const router = express.Router();

router.get('/health', (_req, res) => {
  res.json({
    success: true,
    message: 'VisionAid++ backend is healthy',
    data: {
      status: 'ok',
      service: 'visionaid-backend',
      timestamp: new Date().toISOString(),
    },
    error: null,
  });
});

router.get('/ready', async (_req, res) => {
  const checks = {
    database: false,
    auth: false,
  };

  try {
    const prisma = getPrisma();
    if (prisma) {
      await prisma.$queryRaw`SELECT 1`;
      checks.database = true;
    }
  } catch (error) {
    console.error('[ready] database check failed:', error.message);
  }

  try {
    const supabase = getSupabaseAdmin();
    checks.auth = Boolean(supabase);
  } catch (error) {
    console.error('[ready] auth check failed:', error.message);
  }

  const ready = checks.database && checks.auth;

  res.status(ready ? 200 : 503).json({
    success: ready,
    message: ready ? 'VisionAid++ backend is ready' : 'VisionAid++ backend is not ready',
    data: {
      status: ready ? 'ready' : 'degraded',
      checks,
      timestamp: new Date().toISOString(),
    },
    error: ready ? null : { code: 'SERVICE_NOT_READY' },
  });
});

router.use('/profile', profileRoutes);

module.exports = router;
