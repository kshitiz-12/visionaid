const env = require('../config/env');
const { AppError } = require('../utils/appError');

const SYSTEM_PROMPT = `You are VisionAid, a trusted friend walking beside a person who is blind or has low vision.

Two jobs:
1) Conversation: they may ask about ANYTHING — feelings, plans, knowledge, maths, jokes. Answer that. Do not drag every reply to the camera.
2) Seeing: if a PHOTO is attached, you are the eyes. Name real things. Place them with clock-face directions (12 o'clock is straight ahead, 3 o'clock is right, 9 o'clock is left). Say approximate distance as "very close", "about one metre", or "about two metres". Example: "Water bottle at your 2 o'clock, about one metre away on the table." Never invent objects.

Speak their language. Give a complete spoken answer of 2 to 5 sentences. Finish every sentence with a period.
Never start with their name. Do not greet. Answer the question first.
If they ask what a Hindi word is in English (for example aalu), say the English word clearly, like: "Aalu is called potato in English."
If they asked about food, a word, or knowledge, answer that fully. Do not mention walking, obstacles, or Stop unless the photo shows a real hazard.
Output plain speech only. No Markdown, no asterisks, no hashtags, no bullet lists, no headings.
Never say you are Gemini or ChatGPT. You cannot place calls. If they need a phone call, tell them to say Call or Emergency.`;

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
    lines.push('Do not say their name. Answer directly.');
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

function geminiPayload(userContent, imageBase64) {
  const parts = [{ text: userContent }];
  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: 'image/jpeg',
        data: imageBase64,
      },
    });
  }
  return {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts }],
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 512,
    },
  };
}

function geminiUrl(method) {
  const model = 'gemini-3.6-flash';
  return (
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:${method}` +
    `?key=${encodeURIComponent(env.geminiApiKey)}`
  );
}

async function chatGemini(userContent, imageBase64) {
  const payload = geminiPayload(userContent, imageBase64);
  const response = await fetch(geminiUrl('generateContent'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const lastDetail = body.error?.message || `Gemini failed (${response.status})`;
    console.error('[companion] gemini:', lastDetail);
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

async function* streamGemini(userContent, imageBase64) {
  const payload = geminiPayload(userContent, imageBase64);
  const url = `${geminiUrl('streamGenerateContent')}&alt=sse`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!response.ok || !response.body) {
    const body = await response.json().catch(() => ({}));
    const lastDetail = body.error?.message || `Gemini stream failed (${response.status})`;
    throw new AppError(lastDetail, { statusCode: 502, code: 'AI_UPSTREAM' });
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buf = '';
  let emitted = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    buf += decoder.decode(value, { stream: true });
    const blocks = buf.split('\n\n');
    buf = blocks.pop() || '';
    for (const block of blocks) {
      const line = block.split('\n').find((row) => row.startsWith('data:'));
      if (!line) {
        continue;
      }
      const raw = line.slice(5).trim();
      if (!raw || raw === '[DONE]') {
        continue;
      }
      let parsed;
      try {
        parsed = JSON.parse(raw);
      } catch (_) {
        continue;
      }
      const piece = extractGeminiText(parsed);
      if (!piece) {
        continue;
      }
      let delta = piece;
      if (piece.startsWith(emitted)) {
        delta = piece.slice(emitted.length);
        emitted = piece;
      } else {
        emitted += piece;
      }
      if (delta) {
        yield delta;
      }
    }
  }
}

async function* chatStream(input) {
  if (!hasAnyKey()) {
    throw new AppError(
      'AI companion is not configured. Set OPENAI_API_KEY or GEMINI_API_KEY on the server.',
      { statusCode: 503, code: 'AI_NOT_CONFIGURED' },
    );
  }
  const userContent = buildUserPayload(input);
  const imageBase64 = stripDataUrl(input.imageBase64);
  if (env.geminiApiKey) {
    try {
      yield* streamGemini(userContent, imageBase64);
      return;
    } catch (error) {
      console.error('[companion] stream fallback:', error.message);
      const full = await chatGemini(userContent, imageBase64);
      yield full.text;
      return;
    }
  }
  const reply = await chatOpenAi(userContent, imageBase64);
  yield stripMarkup(reply.text);
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
  chatStream,
  speak,
  hasAnyKey,
};
