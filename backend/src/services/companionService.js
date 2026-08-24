const env = require('../config/env');
const { AppError } = require('../utils/appError');

const SYSTEM_PROMPT = `You are VisionAid, a trusted friend walking beside a person who is blind or has low vision.

Two jobs:
1) Conversation: they may ask about ANYTHING — feelings, plans, knowledge, maths, jokes. Answer that. Do not drag every reply to the camera.
2) Seeing: if a PHOTO is attached, you are the eyes. Name real things. Place them with clock-face directions (12 o'clock is straight ahead, 3 o'clock is right, 9 o'clock is left). Say approximate distance as "very close", "about one metre", or "about two metres". Example: "Water bottle at your 2 o'clock, about one metre away on the table." Never invent objects.

Speak their language. 2–3 short spoken sentences. Warm, not robotic.
Output plain speech only. No Markdown, no asterisks, no hashtags, no bullet lists, no headings.
Never say you are Gemini or ChatGPT. You cannot place calls. Danger: tell them to say Emergency.`;

function hasAnyKey() {
  return Boolean(env.openaiApiKey || env.geminiApiKey);
}

function languageName(code) {
  const c = String(code || 'en').toLowerCase();
  if (c.startsWith('hi')) {
    return 'Hindi';
  }
  if (c.startsWith('en')) {
    return 'English';
  }
  return code || 'the user\'s language';
}

function stripDataUrl(raw) {
  const s = String(raw || '').trim();
  const comma = s.indexOf(',');
  if (s.startsWith('data:') && comma !== -1) {
    return s.slice(comma + 1);
  }
  return s.replace(/\s/g, '');
}

function buildUserPayload({ message, language, userName, sceneSummary, history }) {
  const lines = [];
  lines.push(`User language: ${languageName(language)}. Reply only in that language.`);
  if (userName) {
    lines.push(`Their name: ${userName}.`);
  }
  if (sceneSummary) {
    lines.push(`On-device guesses (may be wrong; trust the photo more):\n${sceneSummary}`);
  }
  if (Array.isArray(history) && history.length > 0) {
    lines.push('Recent conversation:');
    for (const turn of history.slice(-4)) {
      const role = turn.role === 'assistant' ? 'VisionAid' : 'User';
      const text = String(turn.content || '').slice(0, 500);
      if (text) {
        lines.push(`${role}: ${text}`);
      }
    }
  }
  lines.push(`User just said: ${message}`);
  return lines.join('\n\n');
}

async function chatOpenAi(userContent, imageBase64) {
  const userParts = imageBase64
    ? [
        { type: 'text', text: userContent },
        {
          type: 'image_url',
          image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
        },
      ]
    : userContent;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: env.openaiModel,
      temperature: 0.7,
      max_tokens: 220,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userParts },
      ],
    }),
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = body.error?.message || `OpenAI chat failed (${response.status})`;
    throw new AppError(detail, { statusCode: 502, code: 'AI_UPSTREAM' });
  }

  const text = body.choices?.[0]?.message?.content?.trim();
  if (!text) {
    throw new AppError('The assistant returned an empty reply', {
      statusCode: 502,
      code: 'AI_EMPTY',
    });
  }
  return { text, provider: 'openai' };
}

function extractGeminiText(body) {
  const parts = body.candidates?.[0]?.content?.parts || [];
  return parts
    .map((part) => (typeof part.text === 'string' ? part.text : ''))
    .join('')
    .trim();
}

function stripMarkup(text) {
  return String(text || '')
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`([^`]*)`/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/[#*_>~]/g, '')
    .replace(/^\s*[-•]\s+/gm, '')
    .replace(/\s+/g, ' ')
    .trim();
}

async function chatGemini(userContent, imageBase64) {
  // Postman-verified: only gemini-3.6-flash generateContent works for this API key.
  const model = 'gemini-3.6-flash';
  const parts = [{ text: userContent }];
  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: 'image/jpeg',
        data: imageBase64,
      },
    });
  }
  const payload = {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts }],
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 180,
    },
  };

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent` +
    `?key=${encodeURIComponent(env.geminiApiKey)}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const lastDetail = body.error?.message || `Gemini ${model} failed (${response.status})`;
    console.error(`[companion] gemini ${model}:`, lastDetail);
    throw new AppError(lastDetail, { statusCode: 502, code: 'AI_UPSTREAM' });
  }
  const text = stripMarkup(extractGeminiText(body));
  if (!text) {
    throw new AppError('The assistant returned an empty reply', {
      statusCode: 502,
      code: 'AI_EMPTY',
    });
  }
  return { text, provider: 'gemini' };
}

async function chat(input) {
  if (!hasAnyKey()) {
    throw new AppError(
      'AI companion is not configured. Set OPENAI_API_KEY or GEMINI_API_KEY on the server.',
      { statusCode: 503, code: 'AI_NOT_CONFIGURED' },
    );
  }

  const userContent = buildUserPayload(input);
  const imageBase64 = stripDataUrl(input.imageBase64);

  if (env.geminiApiKey) {
    return chatGemini(userContent, imageBase64);
  }
  if (env.openaiApiKey) {
    const reply = await chatOpenAi(userContent, imageBase64);
    return { ...reply, text: stripMarkup(reply.text) };
  }
  throw new AppError(
    'AI companion is not configured. Set GEMINI_API_KEY or OPENAI_API_KEY on the server.',
    { statusCode: 503, code: 'AI_NOT_CONFIGURED' },
  );
}

async function speak({ text, language }) {
  if (!env.openaiApiKey) {
    throw new AppError('Natural voice needs OPENAI_API_KEY on the server.', {
      statusCode: 503,
      code: 'TTS_NOT_CONFIGURED',
    });
  }

  const clipped = String(text || '').trim().slice(0, 4000);
  if (!clipped) {
    throw new AppError('Nothing to speak', { statusCode: 400, code: 'VALIDATION_ERROR' });
  }

  const instructions = String(language || '').toLowerCase().startsWith('hi')
    ? 'Speak warm, clear Hindi. Unhurried. Like a trusted person walking beside them.'
    : 'Speak warm, clear conversational English. Unhurried. Like a trusted person walking beside them.';

  const payload = {
    model: env.openaiTtsModel,
    voice: env.openaiTtsVoice,
    input: clipped,
  };
  if (env.openaiTtsModel.includes('gpt-4o')) {
    payload.instructions = instructions;
  }

  const response = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errBody = await response.text();
    throw new AppError(errBody.slice(0, 300) || `OpenAI TTS failed (${response.status})`, {
      statusCode: 502,
      code: 'TTS_UPSTREAM',
    });
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  return buffer;
}

module.exports = {
  chat,
  speak,
  hasAnyKey,
};
