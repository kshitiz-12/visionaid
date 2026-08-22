const { z } = require('zod');
const env = require('../config/env');
const { chat, speak, hasAnyKey } = require('../services/companionService');

const historyItem = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().trim().min(1).max(2000),
});

const chatSchema = z.object({
  message: z.string().trim().min(1).max(2000),
  language: z.string().trim().max(16).optional().default('en'),
  userName: z.string().trim().max(80).optional().default(''),
  sceneSummary: z.string().trim().max(2000).optional().default(''),
  history: z.array(historyItem).max(12).optional().default([]),
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
      naturalVoice: Boolean(env.openaiApiKey),
    },
    error: null,
  });
}

module.exports = {
  postChat,
  postSpeak,
  getStatus,
};
