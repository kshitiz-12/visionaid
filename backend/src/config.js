import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

function looksLikeGeminiKey(key) {
  const k = (key || '').trim();
  return k.startsWith('AIza');
}

const rawKey = (process.env.GEMINI_API_KEY || '').trim();

export const config = {
  port: Number(process.env.PORT || 8787),
  geminiApiKey: looksLikeGeminiKey(rawKey) ? rawKey : '',
  geminiKeyWarning: rawKey && !looksLikeGeminiKey(rawKey)
    ? 'GEMINI_API_KEY should start with AIza (Google AI Studio). AQ. keys are ignored.'
    : '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  userDataDir: path.resolve(
    root,
    process.env.BROWSER_USER_DATA_DIR || './data/browser-profile',
  ),
  headless: String(process.env.HEADLESS || 'false').toLowerCase() === 'true',
  dataDir: path.join(root, 'data'),
  uploadsDir: path.join(root, 'data', 'uploads'),
};
