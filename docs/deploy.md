# Deploy VisionAid++ Backend (Render) + Connect Flutter

This guide deploys the Node.js backend to **Render**, then points the Flutter app at that live API. You paste Supabase `DATABASE_URL` / `DIRECT_URL` and keys yourself in Render (and locally).

## Architecture after deploy

```
Flutter app ──Supabase Auth──► Supabase
     │
     └── Bearer JWT ──HTTP──► Render backend ──Prisma──► Supabase Postgres
```

Auth stays on Supabase. The backend only verifies JWTs and runs secure server logic.

## 1. Prep your repo

Push the latest code to GitHub (`kshitiz-12/visionaid` or your fork).

Do **not** commit:

- `backend/.env`
- `flutter/dart_defines.json`

## 2. Database setup

```bash
cd backend
npx prisma db push
npx prisma generate
```

## 3. Deploy backend on Render

### Option A — Blueprint (recommended)

1. Open [Render Dashboard](https://dashboard.render.com) → **New** → **Blueprint**
2. Connect the GitHub repo
3. Render reads `render.yaml` at the repo root (`rootDir: backend`)
4. Create the `visionaid-backend` web service

### Option B — Manual Web Service

1. **New** → **Web Service**
2. Connect repo
3. Settings:
   - **Root Directory:** `backend`
   - **Runtime:** Docker
   - **Dockerfile Path:** `./Dockerfile`
   - **Health Check Path:** `/api/health`

## 4. Set Render environment variables

In the service → **Environment**, paste:

| Key | Value |
|-----|--------|
| `NODE_ENV` | `production` |
| `PORT` | `3000` |
| `SUPABASE_URL` | `https://YOUR_REF.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role secret (server only) |
| `SUPABASE_JWT_SECRET` | JWT secret from Supabase settings |
| `DATABASE_URL` | pooled URI (port **6543**) + `?pgbouncer=true` |
| `DIRECT_URL` | direct/session URI (port **5432**) |
| `CORS_ORIGINS` | leave empty for mobile, or add web origins later |
| `GEMINI_API_KEY` | optional |

### Connection string tips

From Supabase → **Project Settings → Database → Connection string**:

- **Transaction pooler** → `DATABASE_URL`
- **Session / direct** → `DIRECT_URL`

URL-encode special characters in the password (`@` → `%40`, etc.).

## 5. Verify deploy

After deploy, open:

```text
https://YOUR-SERVICE.onrender.com/api/health
https://YOUR-SERVICE.onrender.com/api/ready
```

Expect:

- `/api/health` → `200` `{ "data": { "status": "ok" } }`
- `/api/ready` → `200` with `checks.database: true` and `checks.auth: true`

If `/api/ready` is `503`, fix `DATABASE_URL` / Supabase keys and redeploy.

> Free Render services sleep when idle; first request after sleep can take ~30–60s.

## 6. Connect Flutter to the live backend

```powershell
cd flutter
copy dart_defines.example.json dart_defines.json
```

Edit `dart_defines.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_ANON_KEY",
  "API_BASE_URL": "https://YOUR-SERVICE.onrender.com",
  "DEBUG_MODE": "true",
  "PASSWORD_RESET_REDIRECT_TO": "io.supabase.visionaid://login-callback/"
}
```

Run:

```powershell
flutter run --dart-define-from-file=dart_defines.json
```

## 7. End-to-end check

1. Register / sign in (Supabase Auth)
2. Open Profile → should call `GET https://YOUR-SERVICE.onrender.com/api/profile` with Bearer token
3. Save name → `PATCH /api/profile`
4. Confirm row updates in Supabase Table Editor → `profiles`

## Local backend still works

For local API development:

```powershell
cd backend
# .env with same Supabase DB URLs
npm run dev
```

Flutter:

```json
"API_BASE_URL": "http://127.0.0.1:3000"
```

Android emulator local API: use `http://10.0.2.2:3000` instead of `127.0.0.1`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Health OK, ready fails | Bad `DATABASE_URL` / password encoding / migrations not applied |
| Profile 401 | Not signed in, or wrong `SUPABASE_URL` / service role on Render |
| Profile 503 | Prisma cannot reach Postgres |
| Flutter network error | Wrong `API_BASE_URL`, or Render service asleep (retry) |
| CORS errors (web only) | Set `CORS_ORIGINS` to your web origin |

## Security

- Never put `SUPABASE_SERVICE_ROLE_KEY` in Flutter
- Never commit `.env` / `dart_defines.json`
- Prefer Render secret env vars over hardcoding
