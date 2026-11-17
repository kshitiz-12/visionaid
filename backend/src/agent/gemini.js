import { config } from '../config.js';
import { VOICE_STYLE, speakSanitize } from './speak.js';

async function generate(prompt) {
  if (!config.geminiApiKey) {
    return null;
  }
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(config.geminiModel)}:generateContent`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': config.geminiApiKey,
    },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 512,
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini failed: ${res.status} ${err.slice(0, 200)}`);
  }
  const json = await res.json();
  const out =
    json?.candidates?.[0]?.content?.parts?.map((p) => p.text).join(' ') || '';
  return speakSanitize(out);
}

export async function summarizeText(text, { hint = 'Summarize briefly for a blind user.' } = {}) {
  const body = (text || '').trim();
  if (!body) {
    return 'There is nothing to summarize.';
  }
  const out = await generate(
    `${VOICE_STYLE}\n\n${hint}\n\nCONTENT:\n${body.slice(0, 12000)}`,
  );
  if (out == null) {
    const clip = speakSanitize(body.slice(0, 280));
    return `Here is a short offline cut: ${clip}`;
  }
  return out || 'I could not summarize that.';
}

/**
 * One-line headline style for "first mail is from X about Y".
 */
export async function speakHeadline(text, { kind = 'email' } = {}) {
  const body = (text || '').trim();
  if (!body) return 'I could not find anything to read.';
  const out = await generate(
    `${VOICE_STYLE}

Turn this ${kind} page text into ONE short spoken headline, max 2 sentences.
Style example: First mail is from Google about finishing your Windows setup.
Then add: Say tell me in brief if you want more detail.
Do not invent facts. Ignore menus and ads.

CONTENT:
${body.slice(0, 10000)}`,
  );
  if (out == null) {
    return 'I found a message, but Gemini is offline. Say help.';
  }
  return out;
}

/**
 * Longer natural brief from remembered or fresh content.
 */
export async function speakBrief(text, { kind = 'email' } = {}) {
  const body = (text || '').trim();
  if (!body) return 'I do not have anything saved to expand. Open the mail again first.';
  const out = await generate(
    `${VOICE_STYLE}

Give a natural spoken brief about this ${kind} in 4 to 6 short sentences.
Start like you are talking to a friend. Cover who it is from, what they want, and any action needed.
No labels. No markdown.

CONTENT:
${body.slice(0, 12000)}`,
  );
  if (out == null) {
    return speakSanitize(body.slice(0, 400));
  }
  return out;
}

export async function chatAnswer(question, { pageContext = '', nowIso = '' } = {}) {
  const q = (question || '').trim();
  if (!q) return 'Ask me something.';

  const prompt = [
    VOICE_STYLE,
    'Answer in 2 to 5 short spoken sentences.',
    'If the user asks for a joke, tell one clean short joke.',
    'If pageContext is provided, prefer facts from it.',
    nowIso ? `Current local datetime: ${nowIso}` : '',
    pageContext
      ? `Live page context:\n${pageContext.slice(0, 10000)}`
      : '',
    `User said: ${q}`,
  ]
    .filter(Boolean)
    .join('\n\n');

  const out = await generate(prompt);
  if (out == null) {
    return 'I can chat when Gemini is configured. Try open Gmail, or say help.';
  }
  return out || 'I could not answer that.';
}
