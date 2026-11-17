import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';
import { recall, remember, setActiveApp } from '../agent/memory.js';
import { speakBrief, speakHeadline, summarizeText } from '../agent/gemini.js';

async function ensureWhatsApp() {
  setActiveApp('whatsapp');
  const page = await browserAgent.ensure();
  if (!/web\.whatsapp\.com/i.test(page.url())) {
    await browserAgent.navigate('https://web.whatsapp.com/');
  }
  await page.waitForTimeout(1800);
  return page;
}

async function isQrVisible(page) {
  return page
    .evaluate(() => {
      const t = (document.body?.innerText || '').toLowerCase();
      return /scan (this )?qr|use whatsapp on your phone|link with phone/i.test(t);
    })
    .catch(() => false);
}

async function openChat(page, contact) {
  const who = String(contact || '').trim();
  if (!who) return false;
  try {
    const search = page
      .getByRole('textbox', {
        name: /search|Search name|Search or start|Search input/i,
      })
      .first();
    await search.click({ timeout: 8000 });
    await search.fill('');
    await page.waitForTimeout(200);
    await search.fill(who);
    await page.waitForTimeout(1400);
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(200);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1600);
    return true;
  } catch {
    return false;
  }
}

async function openLatestOrUnread(page) {
  try {
    const unread = page.locator('[aria-label*="unread" i]').first();
    if (await unread.isVisible({ timeout: 2000 }).catch(() => false)) {
      await unread.click({ timeout: 4000 });
      await page.waitForTimeout(1500);
      return 'unread';
    }
  } catch {
    /* fall through */
  }
  try {
    const chat = page
      .locator('[data-testid="cell-frame-container"], div[role="listitem"]')
      .first();
    await chat.click({ timeout: 5000 });
    await page.waitForTimeout(1500);
    return 'first';
  } catch {
    return null;
  }
}

async function extractChat(page) {
  return page.evaluate(() => {
    const msgs = [];
    const nodes = document.querySelectorAll(
      '[data-testid="msg-container"], div.message-in, div.message-out, div.copyable-text',
    );
    nodes.forEach((n) => {
      const t = (n.innerText || '').replace(/\s+/g, ' ').trim();
      if (t && t.length > 1 && t.length < 800) msgs.push(t);
    });
    const header =
      document.querySelector(
        '[data-testid="conversation-header"] span[title], header span[title], [data-testid="conversation-info-header"] span',
      )?.getAttribute?.('title') ||
      document.querySelector('[data-testid="conversation-header"], header')
        ?.innerText ||
      '';
    const last = msgs.slice(-10);
    return {
      header: String(header || '')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 120),
      messages: last,
      joined: last.join(' | ').slice(0, 4500),
      lastMessage: last[last.length - 1] || '',
    };
  });
}

async function typeInComposer(page, body) {
  const text = String(body || '').trim();
  if (!text) return false;
  try {
    const box = page
      .getByRole('textbox', { name: /type a message|message/i })
      .first();
    await box.click({ timeout: 8000 });
    await box.fill('');
    await page.waitForTimeout(150);
    await box.fill(text);
    return true;
  } catch {
    try {
      await browserAgent.type('Type a message', text);
      return true;
    } catch {
      return false;
    }
  }
}

async function clearComposer(page) {
  try {
    const box = page
      .getByRole('textbox', { name: /type a message|message/i })
      .first();
    if (await box.isVisible({ timeout: 800 }).catch(() => false)) {
      await box.click();
      await box.fill('');
    }
  } catch {
    /* ignore */
  }
}

export async function openWhatsApp() {
  const page = await ensureWhatsApp();
  if (await isQrVisible(page)) {
    return {
      spoken:
        'WhatsApp Web is open, but it needs a QR scan once. Scan it with your phone, then say last unread message, or last message from mummy.',
    };
  }
  return {
    spoken:
      'WhatsApp is open. You can say last unread message, last message from mummy, who messaged me, or send hello to Kshitiz.',
  };
}

export async function listRecentChats() {
  const page = await ensureWhatsApp();
  if (await isQrVisible(page)) {
    return {
      spoken: 'WhatsApp needs a QR scan first. Scan it, then ask again.',
    };
  }
  await page.waitForTimeout(2200);
  let chats = await page.evaluate(() => {
    const items = [];
    const rows = Array.from(
      document.querySelectorAll(
        '[data-testid="cell-frame-container"], div[role="listitem"], div[aria-label]',
      ),
    );
    for (const row of rows) {
      const label = row.getAttribute('aria-label') || '';
      const t = (row.innerText || label || '').replace(/\s+/g, ' ').trim();
      if (!t || t.length < 3 || t.length > 180) continue;
      if (/search|chat list|type a message|status|communities|channels/i.test(t) && t.length < 40) {
        continue;
      }
      const unread =
        /unread/i.test(label) || /\d+\s*unread/i.test(t) || /\bunread\b/i.test(label);
      // Prefer rows that look like chats (name + preview)
      if (!label && !/\d|am|pm|yesterday|today|:/.test(t.toLowerCase()) && t.split(' ').length < 2) {
        continue;
      }
      items.push({ line: t.slice(0, 110), unread });
      if (items.length >= 8) break;
    }
    // Dedup
    const seen = new Set();
    return items.filter((c) => {
      const k = c.line.slice(0, 40);
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
  });
  if (!chats.length) {
    // Fallback: scrape left pane text blocks
    chats = await page.evaluate(() => {
      const pane =
        document.querySelector('#pane-side, [data-testid="chat-list"]') || document.body;
      const lines = (pane.innerText || '')
        .split('\n')
        .map((l) => l.replace(/\s+/g, ' ').trim())
        .filter((l) => l.length > 2 && l.length < 100);
      return lines.slice(0, 10).map((line) => ({ line, unread: /unread/i.test(line) }));
    });
  }
  remember({
    kind: 'whatsapp_list',
    source: 'whatsapp_chats',
    text: chats.map((c) => c.line).join('\n'),
  });
  if (!chats.length) {
    const qr = await isQrVisible(page);
    return {
      spoken: qr
        ? 'WhatsApp still needs a QR scan. Scan it with your phone, then say who messaged me again.'
        : 'I opened WhatsApp but the chat list is still loading. Wait a few seconds, then say who messaged me again.',
    };
  }
  const spoken = await summarizeText(
    chats.map((c, i) => `${i + 1}. ${c.unread ? '(unread) ' : ''}${c.line}`).join('\n'),
    {
      hint:
        'Speak like a helpful assistant listing recent WhatsApp chats. Name up to 5 people and a short hint of their last line. Mention who has unread. End by saying they can ask last message from a name, or reply saying something.',
    },
  );
  return { spoken, meta: { chats } };
}

export async function readLastMessage({ contact } = {}) {
  const page = await ensureWhatsApp();
  if (await isQrVisible(page)) {
    return {
      spoken: 'WhatsApp needs a QR scan first. Scan it with your phone, then try again.',
    };
  }

  const who = (contact || '').trim();
  if (who) {
    await openChat(page, who);
  } else {
    await openLatestOrUnread(page);
  }

  const extracted = await extractChat(page);
  const view = await browserAgent.readVisibleText({ maxChars: 5000 });
  const contactName = who || extracted.header || 'the open chat';
  const focused = [
    `Contact: ${contactName}`,
    extracted.header ? `Chat header: ${extracted.header}` : '',
    extracted.joined
      ? `Recent messages: ${extracted.joined}`
      : `Visible page: ${view.text}`,
  ]
    .filter(Boolean)
    .join('\n');

  remember({
    kind: 'whatsapp',
    source: 'whatsapp_read',
    contact: contactName,
    title: view.title,
    url: view.url,
    text: focused,
    lastMessage: extracted.lastMessage || '',
  });

  let spoken = await speakHeadline(focused, { kind: 'whatsapp message' });
  if (/download|keep this window|qr code/i.test(spoken) && extracted.joined) {
    spoken = await speakHeadline(
      `Ignore download banners. Read the actual chat. ${focused}`,
      { kind: 'whatsapp message' },
    );
  }
  spoken = spoken.replace(/\bSay\s+Say\b/gi, 'Say');
  if (!/reply|tell me in brief/i.test(spoken)) {
    spoken = `${spoken} You can say tell me in brief, or reply saying your answer.`;
  }
  return { spoken, title: view.title, url: view.url, meta: { contact: contactName } };
}

export async function briefLastWhatsApp(savedText) {
  const spoken = await speakBrief(savedText || '', { kind: 'whatsapp message' });
  return {
    spoken: /reply/i.test(spoken)
      ? spoken
      : `${spoken} Say reply saying, then your words, if you want me to answer them.`,
  };
}

/**
 * Draft a message. Uses remembered contact when user says "reply saying…".
 */
export async function draftWhatsAppMessage({ contact, body, asReply = false } = {}) {
  const page = await ensureWhatsApp();
  if (await isQrVisible(page)) {
    return {
      spoken: 'WhatsApp needs a QR scan first before I can send.',
    };
  }

  const mem = recall();
  const who =
    String(contact || '').trim() ||
    (asReply && mem?.kind === 'whatsapp' ? String(mem.contact || '').trim() : '') ||
    '';
  const text = String(body || '').trim();

  if (!text) {
    return {
      spoken:
        'What should I send? Say for example: reply saying I will call you in 10 minutes.',
      ok: true,
    };
  }

  if (who) {
    await openChat(page, who);
  } else if (asReply) {
    // Assume current open chat
  } else {
    return {
      spoken:
        'Who should I message? Say send hello to mummy, or open a chat first then say reply saying hello.',
      ok: true,
    };
  }

  const typed = await typeInComposer(page, text);
  await browserAgent.screenshot();

  const toName = who || mem?.contact || 'the open chat';
  const pending = confirmGate.propose({
    kind: 'whatsapp_send',
    contact: toName,
    body: text,
    spokenPrompt: typed
      ? `Ready to WhatsApp ${toName}: ${text}. Say confirm to send, or cancel.`
      : `I opened the chat with ${toName}, but could not type clearly. The message is: ${text}. You can type it once, or say cancel.`,
  });

  remember({
    kind: 'whatsapp',
    source: 'whatsapp_draft',
    contact: toName,
    text: `Draft to ${toName}: ${text}`,
    lastMessage: text,
  });

  return { spoken: pending.spokenPrompt, pending };
}

export async function executeWhatsAppSend() {
  const page = await ensureWhatsApp();
  try {
    const sendBtn = page
      .locator('[data-testid="send"], [aria-label="Send"], button[aria-label*="Send" i]')
      .first();
    if (await sendBtn.isVisible({ timeout: 1200 }).catch(() => false)) {
      await sendBtn.click({ timeout: 4000 });
    } else {
      await page.keyboard.press('Enter');
    }
  } catch {
    await page.keyboard.press('Enter');
  }
  await page.waitForTimeout(900);
  await browserAgent.screenshot();
  const mem = recall();
  const who = mem?.contact || 'them';
  return {
    spoken: `WhatsApp message sent to ${who}. You can say last message from ${who}, or send another message.`,
  };
}

export async function cancelWhatsAppDraft() {
  const page = await browserAgent.ensure();
  if (/web\.whatsapp\.com/i.test(page.url())) {
    await clearComposer(page);
  }
  return { spoken: 'Okay, cancelled. The message was not sent.' };
}
