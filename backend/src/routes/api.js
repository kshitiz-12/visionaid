import { Router } from 'express';
import fs from 'fs';
import multer from 'multer';
import path from 'path';
import { readRecentAudit } from '../audit.js';
import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';
import { dispatchSpoken } from '../agent/dispatcher.js';
import { helpText } from '../agent/intent.js';
import { summarizeText } from '../agent/gemini.js';
import { config } from '../config.js';
import { logger } from '../logger.js';

fs.mkdirSync(config.uploadsDir, { recursive: true });

const upload = multer({
  dest: config.uploadsDir,
  limits: { fileSize: 15 * 1024 * 1024 },
});

export const apiRouter = Router();

apiRouter.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'voiceweb-agent',
    version: '1.0.0',
    geminiConfigured: Boolean(config.geminiApiKey),
    geminiWarning: config.geminiKeyWarning || null,
    help: helpText(),
  });
});

apiRouter.get('/ready', async (_req, res) => {
  try {
    const browser = await browserAgent.status();
    res.json({
      ok: true,
      browser,
      pending: confirmGate.get(),
      geminiConfigured: Boolean(config.geminiApiKey),
    });
  } catch (error) {
    res.status(503).json({ ok: false, error: String(error.message || error) });
  }
});

apiRouter.get('/status', async (_req, res) => {
  try {
    const browser = await browserAgent.status();
    res.json({
      browser,
      pending: confirmGate.get(),
      geminiConfigured: Boolean(config.geminiApiKey),
      geminiWarning: config.geminiKeyWarning || null,
    });
  } catch (error) {
    res.status(500).json({ error: String(error.message || error) });
  }
});

apiRouter.get('/audit', (req, res) => {
  const limit = Math.min(Number(req.query.limit || 40), 200);
  res.json({ events: readRecentAudit(limit) });
});

apiRouter.post('/command', async (req, res) => {
  const spoken = String(req.body?.spoken || req.body?.text || '').trim();
  const pdfText = typeof req.body?.pdfText === 'string' ? req.body.pdfText : '';
  if (!spoken) {
    res.status(400).json({ ok: false, error: 'spoken text required' });
    return;
  }
  try {
    const result = await dispatchSpoken(spoken, { pdfText });
    try {
      await browserAgent.screenshot();
    } catch {
      /* browser may not be up */
    }
    res.json({
      ok: result.ok !== false,
      ...result,
      pending: confirmGate.get(),
    });
  } catch (error) {
    logger.error('command_route', { error: String(error.message || error) });
    res.status(500).json({
      ok: false,
      spoken: `Something went wrong: ${String(error.message || error)}`,
      error: String(error.message || error),
    });
  }
});

apiRouter.post('/pdf/summarize', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      res.status(400).json({ ok: false, error: 'file required' });
      return;
    }
    const ext = path.extname(req.file.originalname || '').toLowerCase();
    let text = '';
    if (ext === '.pdf' || req.file.mimetype === 'application/pdf') {
      // Import lib entry directly — package root runs a debug demo under ESM.
      const pdfParse = (await import('pdf-parse/lib/pdf-parse.js')).default;
      const buf = fs.readFileSync(req.file.path);
      const parsed = await pdfParse(buf);
      text = parsed.text || '';
    } else {
      text = fs.readFileSync(req.file.path, 'utf8');
    }
    fs.unlink(req.file.path, () => {});
    if (!text.trim()) {
      res.json({
        ok: false,
        spoken: 'I could not extract text from that file.',
      });
      return;
    }
    const spoken = await summarizeText(text, {
      hint: 'Summarize this document for a blind user in short clear sentences. Include key dates, amounts, and names if present.',
    });
    res.json({ ok: true, spoken, chars: text.length });
  } catch (error) {
    logger.error('pdf_summarize', { error: String(error.message || error) });
    res.status(500).json({
      ok: false,
      spoken: `PDF summary failed: ${String(error.message || error)}`,
      error: String(error.message || error),
    });
  }
});

apiRouter.get('/screenshot', async (_req, res) => {
  try {
    const file = await browserAgent.screenshot();
    if (!fs.existsSync(file)) {
      res.status(404).json({ error: 'no screenshot yet' });
      return;
    }
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(file);
  } catch (error) {
    res.status(500).json({ error: String(error.message || error) });
  }
});

apiRouter.post('/browser/start', async (_req, res) => {
  try {
    await browserAgent.ensure();
    const st = await browserAgent.status();
    res.json({ ok: true, ...st });
  } catch (error) {
    res.status(500).json({ ok: false, error: String(error.message || error) });
  }
});

apiRouter.get('/help', (_req, res) => {
  res.json({ spoken: helpText() });
});
