import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';
import { remember, setActiveApp } from '../agent/memory.js';
import { speakBrief, speakHeadline } from '../agent/gemini.js';

export async function openWhatsApp() {
  const nav = await browserAgent.navigate('https://web.whatsapp.com/');
  setActiveApp('whatsapp');
  return {
    spoken:
      'WhatsApp is open. If you see a QR code, scan it once. Then say last unread message, or last message from mummy.',
    ...nav,
  };
}

export async function readLastMessage({ contact } = {}) {
  await browserAgent.navigate('https://web.whatsapp.com/');
  const page = await browserAgent.ensure();
  await page.waitForTimeout(2000);

  const who = (contact || '').trim();
  if (who) {
    try {
      const search = page
        .getByRole('textbox', { name: /search|Search name|Search or start/i })
        .first();
      await search.click({ timeout: 8000 });
      await search.fill('');
      await search.fill(who);
      await page.waitForTimeout(1500);
      await page.keyboard.press('ArrowDown');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(1500);
    } catch {
      /* chat may already be open */
    }
  }

  const view = await browserAgent.readVisibleText({ maxChars: 8000 });
  remember({
    kind: 'whatsapp',
    source: 'whatsapp_read',
    contact: who,
    title: view.title,
    url: view.url,
    text: view.text,
  });
  const spoken = await speakHeadline(
    `${who ? `Chat with ${who}.` : ''} ${view.text}`,
    { kind: 'whatsapp message' },
  );
  return {
    spoken,
    title: view.title,
    url: view.url,
  };
}

export async function briefLastWhatsApp(savedText) {
  const spoken = await speakBrief(savedText || '', { kind: 'whatsapp message' });
  return { spoken };
}

/**
 * Best-effort: search contact, open chat, type message, wait for confirm to send.
 */
export async function draftWhatsAppMessage({ contact, body }) {
  await browserAgent.navigate('https://web.whatsapp.com/');
  const page = await browserAgent.ensure();

  try {
    const search = page.getByRole('textbox', { name: /search|Search name/i }).first();
    await search.click({ timeout: 8000 });
    await search.fill(contact || '');
    await page.waitForTimeout(1200);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1000);
  } catch {
    /* Fall through */
  }

  if (body) {
    try {
      const box = page.getByRole('textbox', { name: /type a message|message/i }).first();
      await box.click({ timeout: 8000 });
      await box.fill(body);
    } catch {
      await browserAgent.type('Type a message', body);
    }
  }

  await browserAgent.screenshot();
  const pending = confirmGate.propose({
    kind: 'whatsapp_send',
    contact: contact || 'chat',
    body: body || '',
    spokenPrompt: `Ready to send WhatsApp to ${contact || 'the open chat'}: ${body || '(empty)'}. Say confirm to send, or cancel.`,
  });

  return {
    spoken: pending.spokenPrompt,
    pending,
  };
}

export async function executeWhatsAppSend() {
  const page = await browserAgent.ensure();
  await page.keyboard.press('Enter');
  await page.waitForTimeout(800);
  await browserAgent.screenshot();
  return { spoken: 'WhatsApp message sent.' };
}
