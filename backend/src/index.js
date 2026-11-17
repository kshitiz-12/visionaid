import cors from 'cors';
import express from 'express';
import fs from 'fs';
import { config } from './config.js';
import { logger } from './logger.js';
import { apiRouter } from './routes/api.js';

fs.mkdirSync(config.dataDir, { recursive: true });
fs.mkdirSync(config.uploadsDir, { recursive: true });

const app = express();
app.use(cors());
app.use(express.json({ limit: '8mb' }));

app.use((req, _res, next) => {
  if (req.path.startsWith('/api')) {
    logger.info('http', { method: req.method, path: req.path });
  }
  next();
});

app.use('/api', apiRouter);

app.get('/', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html><head><meta charset="utf-8"/><title>VoiceWeb Agent</title>
<style>
body{font-family:system-ui;background:#0b1b14;color:#e8fff4;margin:2rem;max-width:720px}
a{color:#7dffa6} code{background:#123;padding:2px 6px;border-radius:4px}
</style></head><body>
<h1>VoiceWeb Agent</h1>
<p>Backend is running. Use the Flutter app as the voice front-end.</p>
<ul>
<li><a href="/api/health">/api/health</a></li>
<li><a href="/api/ready">/api/ready</a></li>
<li><a href="/api/help">/api/help</a></li>
<li><a href="/api/audit">/api/audit</a> (viva evidence log)</li>
</ul>
<p>Gemini: <code>${config.geminiApiKey ? 'configured' : 'not configured'}</code>
${config.geminiKeyWarning ? `<br/><small>${config.geminiKeyWarning}</small>` : ''}</p>
</body></html>`);
});

app.use((err, _req, res, _next) => {
  logger.error('unhandled', { error: String(err?.message || err) });
  res.status(500).json({ ok: false, error: 'Internal error' });
});

// Bind 0.0.0.0 so Render's port scanner can reach the service (not only localhost).
const host = process.env.HOST || '0.0.0.0';
app.listen(config.port, host, () => {
  logger.info('listening', {
    url: `http://${host}:${config.port}`,
    profile: config.userDataDir,
    headless: config.headless,
    gemini: Boolean(config.geminiApiKey),
  });
  if (config.geminiKeyWarning) {
    logger.warn(config.geminiKeyWarning);
  }
});
