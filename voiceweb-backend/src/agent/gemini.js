import { config } from '../config.js';

export async function summarizeText(text, { hint = 'Summarize briefly for a blind user.' } = {}) {
  const body = (text || '').trim();
  if (!body) {
    return 'There is nothing to summarize.';
  }
  if (!config.geminiApiKey) {
    // Offline fallback for demos without a key.
    const clip = body.slice(0, 500);
    return `Summary (offline): ${clip}${body.length > 500 ? '…' : ''}`;
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(config.geminiModel)}:generateContent?key=${encodeURIComponent(config.geminiApiKey)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [
        {
          role: 'user',
          parts: [
            {
              text: `${hint}\n\nSpeak in short clear sentences.\n\nCONTENT:\n${body.slice(0, 12000)}`,
            },
          ],
        },
      ],
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini failed: ${res.status} ${err.slice(0, 200)}`);
  }
  const json = await res.json();
  const out =
    json?.candidates?.[0]?.content?.parts?.map((p) => p.text).join(' ') || '';
  return out.trim() || 'I could not summarize that.';
}
