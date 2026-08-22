const express = require('express');
const profileRoutes = require('./profileRoutes');
const assistantRoutes = require('./assistantRoutes');
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
  const reasons = [];

  if (!process.env.DATABASE_URL) {
    reasons.push('DATABASE_URL is not set on the server');
  } else {
    const host = (() => {
      try {
        return new URL(process.env.DATABASE_URL).hostname;
      } catch {
        return '';
      }
    })();

    if (host.startsWith('db.') && host.endsWith('.supabase.co')) {
      reasons.push(
        'DATABASE_URL uses db.*.supabase.co (often IPv6-only). On Render use the pooler host aws-0-REGION.pooler.supabase.com',
      );
    }

    try {
      const prisma = getPrisma();
      if (!prisma) {
        reasons.push('Prisma client could not start');
      } else {
        await prisma.$queryRaw`SELECT 1`;
        checks.database = true;
      }
    } catch (error) {
      console.error('[ready] database check failed:', error.message);
      reasons.push(`Database connection failed: ${error.message}`);
    }
  }

  try {
    const supabase = getSupabaseAdmin();
    checks.auth = Boolean(supabase);
    if (!checks.auth) {
      reasons.push('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing');
    }
  } catch (error) {
    console.error('[ready] auth check failed:', error.message);
    reasons.push(`Auth config failed: ${error.message}`);
  }

  const ready = checks.database && checks.auth;

  res.status(ready ? 200 : 503).json({
    success: ready,
    message: ready ? 'VisionAid++ backend is ready' : 'VisionAid++ backend is not ready',
    data: {
      status: ready ? 'ready' : 'degraded',
      checks,
      reasons: ready ? undefined : reasons,
      timestamp: new Date().toISOString(),
    },
    error: ready ? null : { code: 'SERVICE_NOT_READY' },
  });
});

router.use('/profile', profileRoutes);
router.use('/assistant', assistantRoutes);

module.exports = router;
