import { config } from '../config.js';
import { confirmGate } from './confirmGate.js';
import { contextSnapshot } from './memory.js';
import { parseIntent as parseIntentOffline } from './intent.js';
import { logger } from '../logger.js';

const ALLOWED = new Set([
  'help',
  'confirm',
  'cancel',
  'pending_status',
  'time_now',
  'screen_read',
  'summarize',
  'pdf_summarize',
  'gmail_open',
  'gmail_last',
  'gmail_unread',
  'followup_brief',
  'whatsapp_open',
  'whatsapp_read',
  'whatsapp_send',
  'swiggy_order',
  'flipkart_minutes',
  'live_sports',
  'open_url',
  'chat',
]);

/**
 * Fast path only for tiny utterances — everything else goes through Gemini.
 */
function tinyOffline(spoken) {
  const t = (spoken || '').trim();
  if (!t) return { type: 'chat', raw: t, slots: {}, via: 'empty' };
  if (/^(confirm|yes|yeah|yep|ok|okay|haan|haa|हां|हाँ)$/i.test(t)) {
    return { type: 'confirm', raw: t, slots: {}, via: 'offline' };
  }
  if (/^(cancel|no|nope|nahi|नहीं|stop)$/i.test(t)) {
    return { type: 'cancel', raw: t, slots: {}, via: 'offline' };
  }
  if (/^(help|मदद)$/i.test(t)) {
    return { type: 'help', raw: t, slots: {}, via: 'offline' };
  }
  return null;
}

async function geminiRoute(spoken) {
  if (!config.geminiApiKey) return null;

  const ctx = contextSnapshot();
  const pending = confirmGate.get();
  const urlHint = '';

  const prompt = `You convert a blind user's voice command into ONE JSON action for VoiceWeb Agent.

Return ONLY valid JSON, no markdown:
{"type":"<TYPE>","slots":{"contact":"","query":"","body":"","url":""},"reason":"short"}

Allowed TYPE values:
help, confirm, cancel, pending_status, time_now, screen_read, summarize, pdf_summarize,
gmail_open, gmail_last, gmail_unread, followup_brief,
whatsapp_open, whatsapp_read, whatsapp_send,
swiggy_order, flipkart_minutes, live_sports, open_url, chat

Rules:
- Prefer context. If activeApp is whatsapp and user says last/unread/latest message (even without saying WhatsApp), use whatsapp_read — NOT gmail.
- If activeApp is gmail and user says last/unread/latest mail or message about email, use gmail_last or gmail_unread.
- "last unread message" after WhatsApp = whatsapp_read.
- "last mail" / "last email" = gmail_last.
- "tell me in brief" / "more details" / "read more" = followup_brief.
- Flipkart ONLY if user clearly says Flipkart Minutes (not plain Flipkart, not bare milk).
- Swiggy only if food order / Swiggy mentioned.
- Jokes, general questions, unclear small talk = chat.
- Extract contact names (mummy/mom/papa) into slots.contact for WhatsApp.
- Extract food/item into slots.query for swiggy/flipkart_minutes.
- open_url only for google/youtube/maps/http links.

CONTEXT:
${JSON.stringify({ ...ctx, pendingKind: pending?.kind || null, urlHint }, null, 0)}

USER SAID:
${spoken}`;

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
        temperature: 0.1,
        maxOutputTokens: 256,
        responseMimeType: 'application/json',
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`intent Gemini ${res.status}: ${err.slice(0, 160)}`);
  }
  const json = await res.json();
  const raw =
    json?.candidates?.[0]?.content?.parts?.map((p) => p.text).join('') || '';
  const cleaned = raw.replace(/```json|```/g, '').trim();
  const parsed = JSON.parse(cleaned);
  const type = String(parsed.type || 'chat').trim();
  if (!ALLOWED.has(type)) {
    return { type: 'chat', raw: spoken, slots: {}, via: 'gemini-fallback' };
  }
  return {
    type,
    raw: spoken,
    slots: {
      contact: String(parsed.slots?.contact || '').trim(),
      query: String(parsed.slots?.query || '').trim(),
      body: String(parsed.slots?.body || '').trim(),
      url: String(parsed.slots?.url || '').trim(),
    },
    reason: parsed.reason || '',
    via: 'gemini',
  };
}

/**
 * Smart understand: Gemini first (with app context), offline only as backup.
 */
export async function understandSpoken(spoken) {
  const tiny = tinyOffline(spoken);
  if (tiny) return tiny;

  try {
    const routed = await geminiRoute(spoken);
    if (routed) {
      logger.info('understand', {
        via: routed.via,
        type: routed.type,
        reason: routed.reason,
        activeApp: contextSnapshot().activeApp,
      });
      return routed;
    }
  } catch (error) {
    logger.warn('understand_gemini_failed', { error: String(error.message || error) });
  }

  // Context-aware offline rescue before blind regex.
  const ctx = contextSnapshot();
  const soft = (spoken || '').toLowerCase();
  if (
    ctx.activeApp === 'whatsapp' &&
    /\b(last|latest|unread|message|msg|chat)\b/.test(soft)
  ) {
    return {
      type: 'whatsapp_read',
      raw: spoken,
      slots: {
        contact: /\b(mummy|mom|papa|dad)\b/i.test(soft)
          ? soft.match(/\b(mummy|mom|papa|dad)\b/i)[1]
          : '',
      },
      via: 'context-rescue',
    };
  }
  if (
    ctx.activeApp === 'gmail' &&
    /\b(last|latest|unread|mail|email|message)\b/.test(soft)
  ) {
    return {
      type: /\bunread\b/.test(soft) ? 'gmail_unread' : 'gmail_last',
      raw: spoken,
      slots: {},
      via: 'context-rescue',
    };
  }

  const offline = parseIntentOffline(spoken);
  return { ...offline, via: 'offline-regex' };
}
