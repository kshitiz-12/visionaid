/** Make model text safe & natural for TTS (no asterisks / labels). */
export function speakSanitize(text) {
  let t = String(text || '');
  t = t.replace(/\*\*/g, ' ');
  t = t.replace(/\*/g, ' ');
  t = t.replace(/[_`#>~]+/g, ' ');
  t = t.replace(/^\s*[-•]\s+/gm, '');
  t = t.replace(
    /\b(sender|subject|body summary|body|from|to|date|title)\s*:\s*/gi,
    '',
  );
  t = t.replace(/\n+/g, '. ');
  t = t.replace(/\s{2,}/g, ' ');
  t = t.replace(/\s+([,.!?])/g, '$1');
  t = t.replace(/\.{2,}/g, '.');
  return t.trim();
}

export const VOICE_STYLE = [
  'You speak to a blind user over phone-like voice.',
  'Sound like a smart human assistant, not a document reader.',
  'Never use markdown, stars, bullets, numbered lists, or labels like Sender or Subject.',
  'Never spell letter by letter. Never say asterisk or star.',
  'Use plain spoken English sentences only.',
].join(' ');
