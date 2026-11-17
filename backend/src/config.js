import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

function looksLikeGeminiKey(key) {
  const k = (key || '').trim();
  // AIza = legacy standard keys; AQ. = new AI Studio auth keys (default now).
  return k.startsWith('AIza') || k.startsWith('AQ.');
}

const rawKey = (process.env.GEMINI_API_KEY || '').trim();

export const config = {
  port: Number(process.env.PORT || 8787),
  geminiApiKey: looksLikeGeminiKey(rawKey) ? rawKey : '',
  geminiKeyWarning: rawKey && !looksLikeGeminiKey(rawKey)
    ? 'GEMINI_API_KEY looks invalid. Use an AI Studio key (AQ.… or legacy AIza…).'
    : '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-3.8-flash',
  userDataDir: path.resolve(
    root,
    process.env.BROWSER_USER_DATA_DIR || './data/browser-profile',
  ),
  headless: String(process.env.HEADLESS || 'false').toLowerCase() === 'true',
  dataDir: path.join(root, 'data'),
  uploadsDir: path.join(root, 'data', 'uploads'),
};
