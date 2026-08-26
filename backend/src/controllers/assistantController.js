const { z } = require('zod');
const env = require('../config/env');
const { chat, chatStream, speak, hasAnyKey } = require('../services/companionService');

const historyItem = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().trim().min(1).max(2000),
});

const chatSchema = z.object({
  message: z.string().trim().min(1).max(2000),
  language: z.string().trim().max(16).optional().default('en'),
  userName: z.string().trim().max(80).optional().default(''),
  sceneSummary: z.string().trim().max(2000).optional().default(''),
  imageBase64: z.string().max(400_000).optional().default(''),
  history: z.array(historyItem).max(6).optional().default([]),
});

const speakSchema = z.object({
  text: z.string().trim().min(1).max(4000),
  language: z.string().trim().max(16).optional().default('en'),
});

async function postChat(req, res, next) {
  try {
    const payload = chatSchema.parse(req.body);
    const result = await chat(payload);
    res.status(200).json({
      success: true,
      message: 'Companion reply',
      data: {
        reply: result.text,
        provider: result.provider,
        naturalVoice: Boolean(env.openaiApiKey),
      },
      error: null,
    });
  } catch (error) {
    next(error);
  }
}

async function postChatStream(req, res, next) {
  try {
    const payload = chatSchema.parse(req.body);
    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    if (typeof res.flushHeaders === 'function') {
      res.flushHeaders();
    }

    for await (const text of chatStream(payload)) {
      res.write(`data: ${JSON.stringify({ text, done: false })}\n\n`);
      if (typeof res.flush === 'function') {
        res.flush();
      }
    }
    res.write(`data: ${JSON.stringify({ text: '', done: true })}\n\n`);
    res.end();
  } catch (error) {
    if (!res.headersSent) {
      next(error);
      return;
    }
    res.write(
      `data: ${JSON.stringify({ error: error.message || 'stream failed', done: true })}\n\n`,
    );
    res.end();
  }
}

async function postSpeak(req, res, next) {
  try {
    const payload = speakSchema.parse(req.body);
    const audio = await speak(payload);
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).send(audio);
  } catch (error) {
    next(error);
  }
}

function getStatus(_req, res) {
  res.status(200).json({
    success: true,
    message: 'Companion status',
    data: {
      chat: hasAnyKey(),
      gemini: Boolean(env.geminiApiKey),
      openai: Boolean(env.openaiApiKey),
      naturalVoice: Boolean(env.openaiApiKey),
      model: env.geminiApiKey ? env.geminiModel : env.openaiModel,
    },
    error: null,
  });
}

module.exports = {
  postChat,
  postChatStream,
  postSpeak,
  getStatus,
};
