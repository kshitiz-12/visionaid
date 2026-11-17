import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';

export async function openWhatsApp() {
  const nav = await browserAgent.navigate('https://web.whatsapp.com/');
  return {
    spoken: `WhatsApp Web is open. If you see a QR code, scan it once with your phone. Title: ${nav.title}.`,
    ...nav,
  };
}

/**
 * Best-effort: search contact, open chat, type message, wait for confirm to send.
 */
export async function draftWhatsAppMessage({ contact, body }) {
  await browserAgent.navigate('https://web.whatsapp.com/');
  const page = await browserAgent.ensure();

  // Search box
  try {
    const search = page.getByRole('textbox', { name: /search|Search name/i }).first();
    await search.click({ timeout: 8000 });
    await search.fill(contact || '');
    await page.waitForTimeout(1200);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1000);
  } catch {
    // Fall through — user may already have chat open.
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
  // Send button varies; Enter often works in WA Web.
  await page.keyboard.press('Enter');
  await page.waitForTimeout(800);
  await browserAgent.screenshot();
  return { spoken: 'WhatsApp message sent.' };
}
