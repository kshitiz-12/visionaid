const env = require('../config/env');
const { AppError } = require('../utils/appError');

const SYSTEM_PROMPT = `You are VisionAid, a calm companion walking beside a person who is blind or has very low vision. They may live alone.

How you talk:
- Sound like a thoughtful friend, not a robot, IVR, or bullet-list assistant.
- Speak in the user's language (English, Hindi, or whatever they used). Match their register.
- Keep answers short enough to hear: usually 1–4 spoken sentences. Ask one follow-up only when it helps.
- Never say you are ChatGPT, Gemini, or a language model. You are VisionAid.

What you can do:
- Answer questions, explain things, and help plan (errands, cooking steps, what to say in a call, daily routines).
- Use CAMERA SCENE FACTS when present. Those facts come from on-device vision. Do not invent objects that are not listed. If the scene is empty or stale, say you are not sure what is in front of them right now.
- For mobility: be direct. Prefer “stop”, “wait”, “you can walk”, “on your right / left / ahead”, “very close”.
- You cannot place phone calls, send SMS, or open WhatsApp yourself. If they want that, tell them to say call, text, or WhatsApp plus the name.
- If they are in danger, tell them to say Emergency.

Safety:
- No medical diagnosis. No illegal advice. Do not claim you can see the world beyond the scene facts.`;

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

function buildUserPayload({ message, language, userName, sceneSummary, history }) {
  const lines = [];
  lines.push(`User language: ${languageName(language)}. Reply only in that language.`);
  if (userName) {
    lines.push(`Their name: ${userName}.`);
  }
  if (sceneSummary) {
    lines.push(`CAMERA SCENE FACTS (on-device, may be incomplete):\n${sceneSummary}`);
  } else {
    lines.push('CAMERA SCENE FACTS: none for this turn.');
  }
  if (Array.isArray(history) && history.length > 0) {
    lines.push('Recent conversation:');
    for (const turn of history.slice(-12)) {
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

async function chatOpenAi(userContent) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: env.openaiModel,
      temperature: 0.7,
      max_tokens: 350,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userContent },
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

async function chatGemini(userContent) {
  const models = [
    env.geminiModel,
    'gemini-2.0-flash',
    'gemini-2.5-flash',
    'gemini-flash-latest',
  ].filter((name, index, all) => name && all.indexOf(name) === index);

  const payload = {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts: [{ text: userContent }] }],
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 512,
    },
  };

  let lastDetail = 'Gemini chat failed';

  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
    let response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': env.geminiApiKey,
        },
        body: JSON.stringify(payload),
      });
    } catch (error) {
      lastDetail = error.message || 'Gemini network error';
      continue;
    }

    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      lastDetail = body.error?.message || `Gemini ${model} failed (${response.status})`;
      console.error(`[companion] gemini ${model}:`, lastDetail);
      continue;
    }

    const text = extractGeminiText(body);
    if (text) {
      return { text, provider: 'gemini' };
    }
    lastDetail = `Gemini ${model} returned no text`;
    console.error('[companion]', lastDetail, JSON.stringify(body.candidates?.[0]?.finishReason || ''));
  }

  throw new AppError(
    'Gemini could not answer. Check GEMINI_API_KEY and that Generative Language API is enabled.',
    { statusCode: 502, code: 'AI_UPSTREAM' },
  );
}

async function chat(input) {
  if (!hasAnyKey()) {
    throw new AppError(
      'AI companion is not configured. Set OPENAI_API_KEY or GEMINI_API_KEY on the server.',
      { statusCode: 503, code: 'AI_NOT_CONFIGURED' },
    );
  }

  const userContent = buildUserPayload(input);

  if (env.openaiApiKey) {
    return chatOpenAi(userContent);
  }
  return chatGemini(userContent);
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
