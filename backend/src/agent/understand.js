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
  'gmail_reply',
  'gmail_compose',
  'gmail_search',
  'followup_brief',
  'whatsapp_open',
  'whatsapp_read',
  'whatsapp_send',
  'whatsapp_reply',
  'whatsapp_chats',
  'swiggy_order',
  'flipkart_minutes',
  'flipkart_minutes_remove',
  'flipkart_minutes_cart',
  'flipkart_minutes_alt',
  'live_sports',
  'open_url',
  'chat',
]);

function tinyOffline(spoken) {
  const t = (spoken || '').trim();
  if (!t) return { type: 'chat', raw: t, slots: {}, via: 'empty' };
  if (/^(confirm|yes|yeah|yep|ok|okay|haan|haa|हां|हाँ|send it|go ahead)$/i.test(t)) {
    return { type: 'confirm', raw: t, slots: {}, via: 'offline' };
  }
  if (/^(cancel|no|nope|nahi|नहीं|stop|discard)$/i.test(t)) {
    return { type: 'cancel', raw: t, slots: {}, via: 'offline' };
  }
  if (/^(help|मदद)$/i.test(t)) {
    return { type: 'help', raw: t, slots: {}, via: 'offline' };
  }
  return null;
}

/** Heuristic reply/send body extraction for rescue paths. */
function extractReplyBody(spoken) {
  const t = String(spoken || '');
  const m =
    t.match(/\b(?:reply|respond|answer)\s+(?:saying|and say|with|:)\s+(.+)$/i) ||
    t.match(/\b(?:say|bol|bolke|बोलो)\s+(.+)$/i) ||
    t.match(/\b(?:tell them|tell him|tell her)\s+(.+)$/i);
  return (m?.[1] || '').trim();
}

async function geminiRoute(spoken) {
  if (!config.geminiApiKey) return null;

  const ctx = contextSnapshot();
  const pending = confirmGate.get();

  const prompt = `You convert a blind user's voice command into ONE JSON action for VoiceWeb Agent — a smart voice assistant for WhatsApp + Gmail (and a few other apps).

Return ONLY valid JSON, no markdown:
{"type":"<TYPE>","slots":{"contact":"","query":"","body":"","url":"","subject":"","to":""},"reason":"short"}

Allowed TYPE values:
help, confirm, cancel, pending_status, time_now, screen_read, summarize, pdf_summarize,
gmail_open, gmail_last, gmail_unread, gmail_reply, gmail_compose, gmail_search, followup_brief,
whatsapp_open, whatsapp_read, whatsapp_send, whatsapp_reply, whatsapp_chats,
swiggy_order, flipkart_minutes, flipkart_minutes_remove, flipkart_minutes_cart, flipkart_minutes_alt,
live_sports, open_url, chat

Rules — be context-smart like a human assistant:
- Prefer CONTEXT.activeApp and memoryContact. Do not switch apps unless the user clearly asks.
- Phrasing matters: "last unread message" / "unread message" / "who messaged me" → ALWAYS whatsapp_read or whatsapp_chats (never Gmail), even if activeApp is gmail.
- "last mail" / "last email" / "unread mail" → Gmail.
- If activeApp is whatsapp and user says last/unread/latest message → whatsapp_read.
- If activeApp is gmail and user says last/unread/latest mail (with mail/email word) → gmail_last or gmail_unread.
- "tell me in brief" / "more details" / "read more" = followup_brief.
- "tell me in brief" / "more details" / "read more" = followup_brief.
- "who messaged me" / "recent chats" / "chat list" → whatsapp_chats.
- Reply on WhatsApp: "reply saying …" / "tell them …" / "answer saying …" while on WhatsApp or after reading a WA message → whatsapp_reply (slots.body = the words to send). Use memoryContact if no new name.
- Send WhatsApp to a named person: "send hello to mummy" / "message Kshitiz saying hi" → whatsapp_send (slots.contact + slots.body).
- Reply on Gmail: "reply saying …" while on Gmail or after reading mail → gmail_reply (slots.body).
- Compose new mail: "compose mail to X saying Y" / "email X about Z saying …" → gmail_compose (slots.to, slots.subject optional, slots.body).
- "open mail from Google" / "find mail about OTP" → gmail_search (slots.query).
- If pendingKind is whatsapp_send or gmail_send and user affirms → confirm; if they reject → cancel.
- Flipkart Minutes ONLY if user says Flipkart Minutes / Minutes.
- Swiggy only if food order / Swiggy mentioned.
- Jokes, general questions, small talk = chat. If they ask what they can do next on WhatsApp/Gmail, answer as chat with short suggestions.
- Extract contact names (mummy/mom/papa/dad/person names) into slots.contact.
- Extract reply/send text into slots.body carefully (the actual words to send, not the command words).

CONTEXT:
${JSON.stringify({ ...ctx, pendingKind: pending?.kind || null }, null, 0)}

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
        maxOutputTokens: 280,
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
      subject: String(parsed.slots?.subject || '').trim(),
      to: String(parsed.slots?.to || '').trim(),
    },
    reason: parsed.reason || '',
    via: 'gemini',
  };
}

function contextRescue(spoken) {
  const ctx = contextSnapshot();
  const soft = (spoken || '').toLowerCase();
  const body = extractReplyBody(spoken);

  // Reply / send while in an app
  if (
    (ctx.activeApp === 'whatsapp' || ctx.memoryKind === 'whatsapp') &&
    /\b(reply|respond|answer|tell them|tell him|tell her)\b/.test(soft)
  ) {
    return {
      type: 'whatsapp_reply',
      raw: spoken,
      slots: {
        contact: ctx.memoryContact || '',
        body: body || '',
      },
      via: 'context-rescue',
    };
  }
  if (
    (ctx.activeApp === 'gmail' ||
      ctx.memoryKind === 'email' ||
      ctx.memoryKind === 'email_list') &&
    /\b(reply|respond|answer)\b/.test(soft)
  ) {
    return {
      type: 'gmail_reply',
      raw: spoken,
      slots: { body: body || '' },
      via: 'context-rescue',
    };
  }

  if (
    ctx.activeApp === 'whatsapp' &&
    /\b(who messaged|recent chats|chat list|unread chats)\b/.test(soft)
  ) {
    return { type: 'whatsapp_chats', raw: spoken, slots: {}, via: 'context-rescue' };
  }

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
  // Unread *message* = WhatsApp even if we were just in Gmail
  if (/\b(last\s+)?unread\s+message\b|\bunread\s+msg\b|\bwho\s+messaged\b/.test(soft)) {
    if (/\bwho\s+messaged\b/.test(soft)) {
      return { type: 'whatsapp_chats', raw: spoken, slots: {}, via: 'context-rescue' };
    }
    return { type: 'whatsapp_read', raw: spoken, slots: {}, via: 'context-rescue' };
  }

  if (
    ctx.activeApp === 'gmail' &&
    /\b(last|latest|unread|mail|email)\b/.test(soft) &&
    /\b(mail|email|inbox)\b/.test(soft)
  ) {
    return {
      type: /\bunread\b/.test(soft) ? 'gmail_unread' : 'gmail_last',
      raw: spoken,
      slots: {},
      via: 'context-rescue',
    };
  }
  return null;
}

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

  const rescued = contextRescue(spoken);
  if (rescued) return rescued;

  const offline = parseIntentOffline(spoken);
  return { ...offline, via: 'offline-regex' };
}
