import { browserAgent } from '../agent/browserAgent.js';
import { confirmGate } from '../agent/confirmGate.js';
import { recall, remember, setActiveApp } from '../agent/memory.js';
import { speakBrief, speakHeadline, summarizeText } from '../agent/gemini.js';

async function ensureGmail(path = '#inbox') {
  setActiveApp('gmail');
  const page = await browserAgent.ensure();
  const want = `https://mail.google.com/mail/u/0/${path}`;
  if (!/mail\.google\.com/i.test(page.url())) {
    await browserAgent.navigate(want);
  } else if (path === '#inbox' && !/#inbox/i.test(page.url())) {
    // keep thread open if already reading
  } else if (!page.url().includes(path.replace('#', ''))) {
    await browserAgent.navigate(want);
  }
  await page.waitForTimeout(1600);
  return page;
}

async function captureOpenMail(page) {
  const structured = await page.evaluate(() => {
    const from =
      document.querySelector('span.gD[email], span[email].gD, h3 span[email]')?.getAttribute(
        'email',
      ) ||
      document.querySelector('span.gD, span[email]')?.textContent ||
      '';
    const subject =
      document.querySelector('h2.hP, h2[data-thread-perm-id]')?.textContent ||
      document.querySelector('h2')?.textContent ||
      '';
    const body =
      document.querySelector('div.a3s.aiL, div.a3s')?.innerText ||
      document.querySelector('[role="listitem"] .a3s')?.innerText ||
      '';
    return {
      from: String(from || '')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 120),
      subject: String(subject || '')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 160),
      body: String(body || '')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 6000),
    };
  });
  const view = await browserAgent.readVisibleText({ maxChars: 9000 });
  const text = [
    structured.from ? `From: ${structured.from}` : '',
    structured.subject ? `Subject: ${structured.subject}` : '',
    structured.body ? `Body: ${structured.body}` : view.text,
  ]
    .filter(Boolean)
    .join('\n');
  return { ...view, ...structured, text };
}

async function openTopMailAndCapture() {
  const page = await ensureGmail('#inbox');
  try {
    const row = page
      .locator('tr.zA, div[role="row"][data-legacy-message-id], div.UI table tr.zA')
      .first();
    if (await row.isVisible({ timeout: 4000 }).catch(() => false)) {
      await row.click({ timeout: 5000 });
      await page.waitForTimeout(1800);
    }
  } catch {
    /* stay on inbox */
  }
  const captured = await captureOpenMail(page);
  remember({
    kind: 'email',
    source: 'gmail_last',
    from: captured.from || '',
    subject: captured.subject || '',
    title: captured.title,
    url: captured.url,
    text: captured.text,
  });
  return captured;
}

export async function openGmail() {
  await ensureGmail('#inbox');
  return {
    spoken:
      'Gmail is open. Say what is the last mail, any unread mail, reply saying thanks, or compose a mail to someone.',
  };
}

export async function unreadDigest() {
  const page = await ensureGmail('#inbox');
  const view = await browserAgent.readVisibleText({ maxChars: 7000 });
  remember({
    kind: 'email_list',
    source: 'gmail_unread',
    title: view.title,
    url: view.url,
    text: view.text,
  });
  const summary = await summarizeText(view.text, {
    hint:
      'In a friendly voice, name up to 3 recent mails like: One from Google about setup. Two from… Keep it under 4 sentences. Then say they can ask tell me in brief, open the first mail, or reply saying something.',
  });
  return {
    spoken: summary,
    title: view.title,
    url: view.url,
  };
}

export async function lastMailDigest() {
  const view = await openTopMailAndCapture();
  let spoken = await speakHeadline(view.text, { kind: 'email' });
  spoken = spoken.replace(/\bSay\s+Say\b/gi, 'Say');
  if (!/brief|reply/i.test(spoken)) {
    spoken = `${spoken} Say tell me in brief for more, or reply saying your answer.`;
  }
  return {
    spoken,
    title: view.title,
    url: view.url,
  };
}

export async function briefLastMail(savedText) {
  let text = savedText;
  if (!text) {
    const view = await openTopMailAndCapture();
    text = view.text;
  }
  let spoken = await speakBrief(text, { kind: 'email' });
  spoken = spoken.replace(/\bSay\s+Say\b/gi, 'Say').trim();
  if (spoken && !/reply saying/i.test(spoken)) {
    spoken = `${spoken} If you want to answer, say reply saying, then your words.`;
  }
  return { spoken };
}

/** Search inbox and open a matching mail (by sender / subject words). */
export async function openMailByQuery(query) {
  const q = String(query || '').trim();
  if (!q) {
    return lastMailDigest();
  }
  const page = await ensureGmail('#inbox');
  try {
    const search = page.locator('input[aria-label*="Search" i], input[name="q"]').first();
    await search.click({ timeout: 5000 });
    await search.fill(q);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2000);
    const row = page.locator('tr.zA, div[role="row"]').first();
    if (await row.isVisible({ timeout: 4000 }).catch(() => false)) {
      await row.click({ timeout: 5000 });
      await page.waitForTimeout(1600);
    }
  } catch {
    /* fall back to top mail */
    return openTopMailAndCapture().then(async (view) => {
      const spoken = await speakHeadline(view.text, { kind: 'email' });
      return { spoken: `I could not search clearly. ${spoken}` };
    });
  }
  const captured = await captureOpenMail(page);
  remember({
    kind: 'email',
    source: 'gmail_search',
    from: captured.from || '',
    subject: captured.subject || '',
    query: q,
    title: captured.title,
    url: captured.url,
    text: captured.text,
  });
  let spoken = await speakHeadline(captured.text, { kind: 'email' });
  spoken = `${spoken} Say tell me in brief, or reply saying your answer.`;
  return { spoken, title: captured.title, url: captured.url };
}

/**
 * Reply to the open / last remembered mail. Types body, waits for confirm.
 */
export async function draftGmailReply({ body } = {}) {
  const text = String(body || '').trim();
  if (!text) {
    return {
      spoken:
        'What should the reply say? For example: reply saying thanks, I will check and get back.',
    };
  }

  let page = await browserAgent.ensure();
  if (!/mail\.google\.com/i.test(page.url())) {
    await openTopMailAndCapture();
    page = await browserAgent.ensure();
  }

  // Ensure a thread is open
  if (/#inbox\/?$/i.test(page.url()) || /#inbox$/i.test(page.url())) {
    try {
      const row = page.locator('tr.zA').first();
      if (await row.isVisible({ timeout: 2000 }).catch(() => false)) {
        await row.click({ timeout: 4000 });
        await page.waitForTimeout(1400);
      }
    } catch {
      /* ignore */
    }
  }

  try {
    const reply = page
      .getByRole('button', { name: /^reply$/i })
      .or(page.locator('[aria-label*="Reply" i]').first())
      .first();
    await reply.click({ timeout: 6000 });
    await page.waitForTimeout(1000);
  } catch {
    try {
      await page.keyboard.press('r');
      await page.waitForTimeout(1000);
    } catch {
      /* ignore */
    }
  }

  try {
    const box = page
      .locator('div[aria-label*="Message Body" i], div[role="textbox"][aria-label*="Body" i], div.Am.Al')
      .first();
    await box.click({ timeout: 6000 });
    await box.fill(text);
  } catch {
    try {
      await page.keyboard.type(text, { delay: 15 });
    } catch {
      return {
        spoken:
          'I opened reply, but could not type the message clearly. You can type once on the PC, or say cancel.',
      };
    }
  }

  await browserAgent.screenshot();
  const mem = recall();
  const whom = mem?.from || mem?.subject || 'this mail';
  const pending = confirmGate.propose({
    kind: 'gmail_send',
    body: text,
    to: whom,
    spokenPrompt: `Ready to reply to ${whom}: ${text}. Say confirm to send, or cancel.`,
  });
  remember({
    kind: 'email',
    source: 'gmail_reply_draft',
    from: mem?.from || '',
    subject: mem?.subject || '',
    text: mem?.text || `Reply draft: ${text}`,
    lastMessage: text,
  });
  return { spoken: pending.spokenPrompt, pending };
}

/**
 * Compose a new mail.
 */
export async function draftGmailCompose({ to, subject, body } = {}) {
  const recipient = String(to || '').trim();
  const subj = String(subject || '').trim() || 'Hello';
  const text = String(body || '').trim();
  if (!recipient) {
    return {
      spoken:
        'Who should I email? Say compose mail to Google saying hello, or give a name or address.',
    };
  }
  if (!text) {
    return {
      spoken: `What should I write to ${recipient}? Say compose mail to ${recipient} saying your message.`,
    };
  }

  const page = await ensureGmail('#inbox');
  try {
    const compose = page.getByRole('button', { name: /compose/i }).first();
    await compose.click({ timeout: 6000 });
    await page.waitForTimeout(1000);
  } catch {
    return { spoken: 'I could not find the Compose button. Open Gmail on the PC and try again.' };
  }

  try {
    const toBox = page.locator('input[peoplekit-id], textarea[name="to"], input[aria-label*="To" i]').first();
    await toBox.click({ timeout: 4000 });
    await toBox.fill(recipient);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(400);
  } catch {
    /* continue */
  }

  try {
    const subBox = page.locator('input[name="subjectbox"], input[aria-label*="Subject" i]').first();
    await subBox.click({ timeout: 3000 });
    await subBox.fill(subj);
  } catch {
    /* continue */
  }

  try {
    const box = page
      .locator('div[aria-label*="Message Body" i], div[role="textbox"][aria-label*="Body" i], div.Am.Al')
      .first();
    await box.click({ timeout: 4000 });
    await box.fill(text);
  } catch {
    await page.keyboard.type(text, { delay: 12 });
  }

  await browserAgent.screenshot();
  const pending = confirmGate.propose({
    kind: 'gmail_send',
    body: text,
    to: recipient,
    subject: subj,
    spokenPrompt: `Ready to email ${recipient} about ${subj}: ${text}. Say confirm to send, or cancel.`,
  });
  return { spoken: pending.spokenPrompt, pending };
}

export async function executeGmailSend() {
  const page = await browserAgent.ensure();
  try {
    const send = page
      .getByRole('button', { name: /^send$/i })
      .or(page.locator('[aria-label*="Send" i]').first())
      .first();
    if (await send.isVisible({ timeout: 2000 }).catch(() => false)) {
      await send.click({ timeout: 4000 });
    } else {
      await page.keyboard.press('Control+Enter');
    }
  } catch {
    await page.keyboard.press('Control+Enter');
  }
  await page.waitForTimeout(1200);
  await browserAgent.screenshot();
  const mem = recall();
  return {
    spoken: `Mail sent${mem?.from || mem?.contact ? '' : ''}. You can say what is the last mail, or compose another.`,
  };
}

export async function cancelGmailDraft() {
  const page = await browserAgent.ensure();
  if (/mail\.google\.com/i.test(page.url())) {
    try {
      await page.keyboard.press('Escape');
      await page.waitForTimeout(400);
      const discard = page.getByRole('button', { name: /discard/i }).first();
      if (await discard.isVisible({ timeout: 800 }).catch(() => false)) {
        await discard.click();
      }
    } catch {
      /* ignore */
    }
  }
  return { spoken: 'Okay, cancelled. The mail was not sent.' };
}
