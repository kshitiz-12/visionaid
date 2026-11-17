import { browserAgent } from '../agent/browserAgent.js';
import { remember, setActiveApp } from '../agent/memory.js';
import { speakBrief, speakHeadline, summarizeText } from '../agent/gemini.js';

export async function openGmail() {
  const nav = await browserAgent.navigate('https://mail.google.com/mail/u/0/#inbox');
  setActiveApp('gmail');
  return {
    spoken: 'Gmail is open. Say what is the last mail when you are ready.',
    ...nav,
  };
}

async function openTopMailAndCapture() {
  await browserAgent.navigate('https://mail.google.com/mail/u/0/#inbox');
  await new Promise((r) => setTimeout(r, 1600));
  const page = await browserAgent.ensure();

  try {
    const row = page
      .locator('tr.zA, div[role="row"][data-legacy-message-id], div.UI table tr')
      .first();
    if (await row.isVisible({ timeout: 4000 }).catch(() => false)) {
      await row.click({ timeout: 5000 });
      await page.waitForTimeout(1800);
    }
  } catch {
    /* stay on inbox list */
  }

  const view = await browserAgent.readVisibleText({ maxChars: 10000 });
  remember({
    kind: 'email',
    source: 'gmail_last',
    title: view.title,
    url: view.url,
    text: view.text,
  });
  return view;
}

export async function unreadDigest() {
  await browserAgent.navigate('https://mail.google.com/mail/u/0/#inbox');
  await new Promise((r) => setTimeout(r, 1500));
  const page = await browserAgent.readVisibleText({ maxChars: 7000 });
  remember({
    kind: 'email_list',
    source: 'gmail_unread',
    title: page.title,
    url: page.url,
    text: page.text,
  });
  const summary = await summarizeText(page.text, {
    hint:
      'In a friendly voice, name up to 3 recent mails like: One from Google about setup. Two from… Keep it under 4 sentences. Then say they can ask tell me in brief about the first one.',
  });
  return {
    spoken: summary,
    title: page.title,
    url: page.url,
  };
}

/** Short human headline for the latest mail. */
export async function lastMailDigest() {
  const view = await openTopMailAndCapture();
  const spoken = await speakHeadline(view.text, { kind: 'email' });
  return {
    spoken,
    title: view.title,
    url: view.url,
  };
}

/** Expand the remembered mail (or re-open top mail). */
export async function briefLastMail(savedText) {
  let text = savedText;
  if (!text) {
    const view = await openTopMailAndCapture();
    text = view.text;
  }
  const spoken = await speakBrief(text, { kind: 'email' });
  return { spoken };
}
