# Supabase Auth Setup (VisionAid++)

Wire real Supabase credentials so login, register, forgot password, and profile work end-to-end.

## 1. Create a Supabase project

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. **New project** → pick org, name (`visionaid`), region, database password
3. Wait until the project is ready

## 2. Copy API keys

**Project Settings → API**

| Value | Where it goes |
|-------|----------------|
| Project URL | Flutter `SUPABASE_URL` + Backend `SUPABASE_URL` |
| `anon` `public` key | Flutter only (`SUPABASE_ANON_KEY`) |
| `service_role` `secret` key | Backend only (`SUPABASE_SERVICE_ROLE_KEY`) — never in Flutter |

**Project Settings → API → JWT Settings** (or Legacy JWT secret)

| Value | Where it goes |
|-------|----------------|
| JWT Secret | Backend `SUPABASE_JWT_SECRET` (optional backup; auth uses service role `getUser`) |

## 3. Copy database connection strings

**Project Settings → Database → Connection string**

Use the **URI** format:

- **Transaction pooler** (port `6543`) → Backend `DATABASE_URL`  
  Append `?pgbouncer=true` if not already present.
- **Direct / Session** (port `5432`) → Backend `DIRECT_URL`

Replace `[YOUR-PASSWORD]` with the database password you set at project creation.

Example shapes:

```env
DATABASE_URL=postgresql://postgres.xxxx:PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.xxxx:PASSWORD@aws-0-ap-south-1.pooler.supabase.com:5432/postgres
```

## 4. Apply SQL migrations

In Supabase **SQL Editor**, run these files **in order**:

1. `supabase/migrations/20250821000000_initial_schema.sql`
2. `supabase/migrations/20250821000001_rls_policies.sql`
3. `supabase/migrations/20250821000002_force_rls.sql`

Or with CLI (if linked):

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

> If `CREATE EXTENSION vector` fails, enable **pgvector** under Database → Extensions, then re-run that statement.

## 5. Auth settings

**Authentication → Providers → Email**

- Enable Email provider
- For local testing you may disable “Confirm email”
- For production, enable confirmations

**Authentication → URL Configuration**

Add redirect URL:

```text
io.supabase.visionaid://login-callback/
```

Also keep Site URL as your preferred URL (can be `http://127.0.0.1:3000` for now).

## 6. Backend `.env`

```bash
cd backend
copy .env.example .env
```

Fill:

```env
PORT=3000
NODE_ENV=development
CORS_ORIGINS=http://127.0.0.1:3000
SUPABASE_URL=https://YOUR_REF.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_JWT_SECRET=your-jwt-secret
DATABASE_URL=postgresql://...:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://...:5432/postgres
```

Then:

```bash
npm install
npm run db:generate
npm run dev
```

Check:

- http://127.0.0.1:3000/api/health
- http://127.0.0.1:3000/api/ready  (needs valid `DATABASE_URL` + Supabase keys)

## 7. Flutter dart defines

```bash
cd flutter
copy dart_defines.example.json dart_defines.json
```

Edit `dart_defines.json` with Project URL + **anon** key only.

Run:

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

## 8. End-to-end checklist

- [ ] Register a new user (email + password + display name)
- [ ] Confirm a `profiles` row appears in Table Editor
- [ ] Confirm a `settings` row appears for that user
- [ ] Sign out → sign in again
- [ ] Forgot password sends email (if confirmations/SMTP enabled)
- [ ] Profile page loads (needs backend running + JWT)
- [ ] Save profile updates `full_name`
- [ ] App reopen restores session (stays on home)

## Security reminders

- Never commit `.env` or `dart_defines.json`
- Never put `service_role` in Flutter
- Camera frames stay on device by default (future vision features)
