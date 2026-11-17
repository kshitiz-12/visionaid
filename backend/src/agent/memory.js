/**
 * Short-lived conversation + active app context.
 * So "last unread message" after WhatsApp stays on WhatsApp, not Gmail.
 */
let last = null;
let activeApp = 'none'; // gmail | whatsapp | swiggy | flipkart | browser | none
let lastIntentType = '';

export function setActiveApp(app) {
  activeApp = app || 'none';
}

export function getActiveApp() {
  return activeApp;
}

export function setLastIntentType(type) {
  lastIntentType = type || '';
}

export function getLastIntentType() {
  return lastIntentType;
}

export function remember(payload) {
  last = {
    ...payload,
    ts: Date.now(),
  };
  if (
    payload?.kind === 'email' ||
    payload?.kind === 'email_list'
  ) {
    activeApp = 'gmail';
  }
  if (payload?.kind === 'whatsapp' || payload?.kind === 'whatsapp_list') {
    activeApp = 'whatsapp';
  }
  return last;
}

export function recall({ maxAgeMs = 10 * 60 * 1000 } = {}) {
  if (!last) return null;
  if (Date.now() - last.ts > maxAgeMs) return null;
  return last;
}

export function clearMemory() {
  last = null;
}

export function contextSnapshot() {
  return {
    activeApp,
    lastIntentType,
    memoryKind: last?.kind || null,
    memoryContact: last?.contact || null,
    memoryAgeSec: last ? Math.round((Date.now() - last.ts) / 1000) : null,
  };
}
