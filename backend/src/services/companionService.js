const env = require('../config/env');
const { AppError } = require('../utils/appError');

const SYSTEM_PROMPT = `You are VisionAid, a calm friend beside someone who is blind or has low vision. Sound like a person, not a detector.

Decide the job from THIS turn:
- Knowledge, feelings, plans, maths, jokes, translation: answer that. Do not mention the camera or walking unless they asked.
- Seeing: only if a PHOTO is attached this turn. Name real things. Place them with left, slight left, ahead, slight right, or right. Distance: close, about one metre, or about two metres. Never invent objects. One or two spoken sentences unless they asked for more detail.
- Follow-up: use chat history. If they say "that" or "it", they mean the last thing you described.

Language:
- English replies: clear English. Finish every sentence with a period.
- Hindi replies: 100 percent Devanagari script only. Example: आलू, not Aalu. Use । at the end of sentences. Never mix Latin letters into Hindi words.
If they ask what a Hindi word is in English, still write the Hindi word in Devanagari, then the English word. Example: "आलू is called potato in English."

Output plain speech only. No Markdown, no asterisks, no hashtags, no bullet lists, no headings, no code.
Keep it short for voice: usually one to three spoken sentences. Lead with the answer.
Never start with their name. Do not greet. Answer first.
Never say you are Gemini or ChatGPT. You cannot place calls. For a phone call, tell them to say Call or Emergency.`;

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

function buildUserPayload({ message, language, userName, sceneSummary, history, imageBase64 }) {
  const lines = [];
  lines.push(`User language: ${languageName(language)}. Reply only in that language.`);
  if (String(language || '').toLowerCase().startsWith('hi')) {
    lines.push('Hindi must be Devanagari only. Do not transliterate.');
  }
  if (userName) {
    lines.push(`Their name is ${userName}. Do not start with it.`);
  }
  const hasPhoto = Boolean(stripDataUrl(imageBase64));
  if (hasPhoto) {
    lines.push('A photo is attached. You are their eyes for this turn.');
    if (sceneSummary) {
      lines.push(`On-device guesses (may be wrong; trust the photo):\n${sceneSummary}`);
    }
  } else if (sceneSummary) {
    lines.push(
      `No new photo. Scene memory from earlier (do not invent new objects):\n${sceneSummary}`,
    );
  } else {
    lines.push('No photo this turn. Answer from knowledge and the conversation.');
  }
  if (Array.isArray(history) && history.length > 0) {
    lines.push('Recent conversation:');
    for (const turn of history.slice(-6)) {
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
      max_tokens: 360,
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
  const candidates = Array.isArray(body?.candidates) ? body.candidates : [];
  const chunks = [];
  for (const candidate of candidates) {
    if (typeof candidate?.text === 'string') {
      chunks.push(candidate.text);
    }
    const parts = candidate?.content?.parts || [];
    for (const part of parts) {
      if (part?.thought) {
        continue;
      }
      if (typeof part?.text === 'string' && part.text.trim()) {
        chunks.push(part.text);
      }
    }
  }
  return chunks.join('').trim();
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

function geminiModels() {
  // Product uses Gemini 3.6 Flash only — other Flash IDs fail on this key.
  const preferred = (env.geminiModel || 'gemini-3.6-flash').trim();
  return [preferred || 'gemini-3.6-flash'];
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
  // 3.6 Flash is a thinking model. Small budget + no thought echo keeps voice replies filled.
  return {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts }],
    generationConfig: {
      temperature: 0.55,
      maxOutputTokens: 768,
      thinkingConfig: {
        thinkingBudget: 512,
        includeThoughts: false,
      },
    },
  };
}

function geminiUrl(method, model) {
  return (
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:${method}` +
    `?key=${encodeURIComponent(env.geminiApiKey)}`
  );
}

async function fetchWithTimeout(url, options, ms = 22000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...options, signal: ctrl.signal });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new AppError('Gemini timed out', { statusCode: 504, code: 'AI_UPSTREAM' });
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

async function generateGemini(userContent, imageBase64, model) {
  const payload = geminiPayload(userContent, imageBase64);
  const response = await fetchWithTimeout(geminiUrl('generateContent', model), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const lastDetail = body.error?.message || `Gemini failed (${response.status})`;
    throw new AppError(lastDetail, { statusCode: 502, code: 'AI_UPSTREAM' });
  }
  const finish = body.candidates?.[0]?.finishReason;
  const text = stripMarkup(extractGeminiText(body));
  if (!text) {
    console.error('[companion] gemini empty', model, finish || 'no-finish');
    throw new AppError('The assistant returned an empty reply', {
      statusCode: 502,
      code: 'AI_EMPTY',
    });
  }
  return { text, provider: 'gemini' };
}

async function chatGemini(userContent, imageBase64) {
  let lastError;
  for (const model of geminiModels()) {
    try {
      return await generateGemini(userContent, imageBase64, model);
    } catch (error) {
      lastError = error;
      console.error('[companion] gemini:', model, error.message);
    }
  }
  throw lastError || new AppError('Gemini failed', { statusCode: 502, code: 'AI_UPSTREAM' });
}

async function* streamGemini(userContent, imageBase64, model) {
  const payload = geminiPayload(userContent, imageBase64);
  const url = `${geminiUrl('streamGenerateContent', model)}&alt=sse`;
  const response = await fetchWithTimeout(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }, 25000);
  if (!response.ok || !response.body) {
    const body = await response.json().catch(() => ({}));
    const lastDetail = body.error?.message || `Gemini stream failed (${response.status})`;
    throw new AppError(lastDetail, { statusCode: 502, code: 'AI_UPSTREAM' });
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buf = '';
  let emitted = '';
  const started = Date.now();
  while (true) {
    if (Date.now() - started > 28000) {
      throw new AppError('Gemini stream timed out', { statusCode: 504, code: 'AI_UPSTREAM' });
    }
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
      const cleaned = stripMarkup(delta);
      if (cleaned) {
        yield cleaned;
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
    const models = geminiModels();
    // Stream only the first model — cascading streams was hanging for ~90s.
    let lastError;
    try {
      let gotText = false;
      for await (const piece of streamGemini(userContent, imageBase64, models[0])) {
        if (piece) {
          gotText = true;
          yield piece;
        }
      }
      if (gotText) {
        return;
      }
      lastError = new AppError('The assistant returned an empty reply', {
        statusCode: 502,
        code: 'AI_EMPTY',
      });
    } catch (error) {
      lastError = error;
      console.error('[companion] stream:', models[0], error.message);
    }
    try {
      const full = await chatGemini(userContent, imageBase64);
      yield full.text;
      return;
    } catch (error) {
      throw lastError || error;
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

async function requestSpeech(model, voice, input, instructions) {
  const payload = {
    model,
    voice,
    input,
    response_format: 'mp3',
  };
  if (String(model).includes('gpt-4o')) {
    payload.instructions = instructions;
  }
  return fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.openaiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
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

  const hindi = String(language || '').toLowerCase().startsWith('hi');
  const instructions = hindi
    ? 'Voice: warm, clear, unhurried Hindi. Like ChatGPT Advanced Voice. Speak as a trusted person beside someone who cannot see. No announcer tone.'
    : 'Voice: warm, clear, unhurried conversational English. Like ChatGPT Advanced Voice. Speak as a trusted person beside someone who cannot see. No announcer tone.';

  const preferred = env.openaiTtsModel || 'gpt-4o-mini-tts';
  const preferredVoice = env.openaiTtsVoice || 'coral';
  const models = [...new Set([preferred, 'gpt-4o-mini-tts', 'tts-1-hd'])];
  const tts1Voices = new Set(['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']);

  let lastDetail = 'OpenAI TTS failed';
  for (const model of models) {
    const voice = String(model).includes('gpt-4o')
      ? preferredVoice
      : (tts1Voices.has(preferredVoice) ? preferredVoice : 'nova');
    const response = await requestSpeech(model, voice, clipped, instructions);
    if (response.ok) {
      return Buffer.from(await response.arrayBuffer());
    }
    lastDetail = (await response.text()).slice(0, 300) || `OpenAI TTS failed (${response.status})`;
    console.error('[companion] tts', model, lastDetail);
  }
  throw new AppError(lastDetail, { statusCode: 502, code: 'TTS_UPSTREAM' });
}

module.exports = {
  chat,
  chatStream,
  speak,
  hasAnyKey,
};
