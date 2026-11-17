import { browserAgent } from '../agent/browserAgent.js';
import { summarizeText } from '../agent/gemini.js';

export async function openGmail() {
  const nav = await browserAgent.navigate('https://mail.google.com/mail/u/0/#inbox');
  return {
    spoken: `Gmail is open. Title: ${nav.title}. If you are not logged in, sign in once in the browser window.`,
    ...nav,
  };
}

export async function unreadDigest() {
  await browserAgent.navigate('https://mail.google.com/mail/u/0/#inbox');
  const page = await browserAgent.readVisibleText({ maxChars: 6000 });
  // Heuristic: unread rows often include "unread" in aria; we summarize visible inbox text.
  const summary = await summarizeText(page.text, {
    hint: 'From this Gmail inbox view, list up to 5 likely messages with sender and subject if visible. If login wall, say user must sign in.',
  });
  return {
    spoken: summary,
    title: page.title,
    url: page.url,
  };
}
