const { z } = require('zod');
const dotenv = require('dotenv');

dotenv.config();

function withSsl(url) {
  if (!url) {
    return '';
  }
  if (/sslmode=/i.test(url)) {
    return url;
  }
  return url.includes('?') ? `${url}&sslmode=require` : `${url}?sslmode=require`;
}

const envSchema = z.object({
  PORT: z.coerce.number().int().min(0).default(3000),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  DATABASE_URL: z.string().min(1).optional().or(z.literal('')),
  DIRECT_URL: z.string().optional().or(z.literal('')),
  SUPABASE_URL: z.string().url().optional().or(z.literal('')),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1).optional().or(z.literal('')),
  SUPABASE_JWT_SECRET: z.string().optional().or(z.literal('')),
  CORS_ORIGINS: z.string().optional().or(z.literal('')),
  GEMINI_API_KEY: z.string().optional().or(z.literal('')),
  OPENAI_API_KEY: z.string().optional().or(z.literal('')),
  OPENAI_MODEL: z.string().optional().or(z.literal('')),
  OPENAI_TTS_MODEL: z.string().optional().or(z.literal('')),
  OPENAI_TTS_VOICE: z.string().optional().or(z.literal('')),
  GEMINI_MODEL: z.string().optional().or(z.literal('')),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment configuration:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

const raw = parsed.data;
const isProduction = raw.NODE_ENV === 'production';

const databaseUrl = withSsl(raw.DATABASE_URL || '');
const directUrl = withSsl(raw.DIRECT_URL || '');

// Prisma reads process.env — keep normalized URLs there.
if (databaseUrl) {
  process.env.DATABASE_URL = databaseUrl;
}
if (directUrl) {
  process.env.DIRECT_URL = directUrl;
}

if (isProduction) {
  const missing = [];
  if (!databaseUrl) missing.push('DATABASE_URL');
  if (!raw.SUPABASE_URL) missing.push('SUPABASE_URL');
  if (!raw.SUPABASE_SERVICE_ROLE_KEY) missing.push('SUPABASE_SERVICE_ROLE_KEY');

  if (missing.length > 0) {
    console.error(`Missing required production env vars: ${missing.join(', ')}`);
    process.exit(1);
  }
}

const corsOrigins = (raw.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const env = {
  port: raw.PORT,
  nodeEnv: raw.NODE_ENV,
  isProduction,
  databaseUrl,
  directUrl,
  supabaseUrl: raw.SUPABASE_URL || '',
  supabaseServiceRoleKey: raw.SUPABASE_SERVICE_ROLE_KEY || '',
  supabaseJwtSecret: raw.SUPABASE_JWT_SECRET || '',
  corsOrigins,
  geminiApiKey: raw.GEMINI_API_KEY || '',
  openaiApiKey: raw.OPENAI_API_KEY || '',
  openaiModel: raw.OPENAI_MODEL || 'gpt-4o-mini',
  openaiTtsModel: raw.OPENAI_TTS_MODEL || 'tts-1-hd',
  openaiTtsVoice: raw.OPENAI_TTS_VOICE || 'nova',
  geminiModel: raw.GEMINI_MODEL || 'gemini-2.5-flash',
};

module.exports = env;
