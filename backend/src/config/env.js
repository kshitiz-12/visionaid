const { z } = require('zod');
const dotenv = require('dotenv');

dotenv.config();

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
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment configuration:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

const raw = parsed.data;
const isProduction = raw.NODE_ENV === 'production';

if (isProduction) {
  const missing = [];
  if (!raw.DATABASE_URL) missing.push('DATABASE_URL');
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
  databaseUrl: raw.DATABASE_URL || '',
  directUrl: raw.DIRECT_URL || '',
  supabaseUrl: raw.SUPABASE_URL || '',
  supabaseServiceRoleKey: raw.SUPABASE_SERVICE_ROLE_KEY || '',
  supabaseJwtSecret: raw.SUPABASE_JWT_SECRET || '',
  corsOrigins,
  geminiApiKey: raw.GEMINI_API_KEY || '',
};

module.exports = env;
