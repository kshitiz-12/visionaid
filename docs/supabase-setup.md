# Fix Supabase DB (Render)

## Why `/api/ready` fails on Render

Error:

`Can't reach database server at db.….supabase.co:6543`

**Cause:** `db.PROJECT.supabase.co` is often **IPv6-only**. Render (free) usually needs **IPv4**.

Local PC can connect; Render cannot.

## Fix (2 minutes)

1. Open Supabase → **Project Settings → Database**
2. Open **Connection string** → URI
3. Choose **Pooler** connections (not “Direct”):

### `DATABASE_URL` (Transaction pooler)

- Host like: `aws-0-ap-south-1.pooler.supabase.com` (NOT `db.…`)
- Port: **6543**
- User often: `postgres.YOUR_PROJECT_REF`
- Add: `?pgbouncer=true`

Example shape:

```text
postgresql://postgres.fogmbmvvvzemdcyywsrd:YOUR_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true
```

### `DIRECT_URL` (Session pooler or Direct)

- Port **5432**
- Same password
- Prefer pooler session host if shown, or direct `db.…:5432` for migrations only

Example shape:

```text
postgresql://postgres.fogmbmvvvzemdcyywsrd:YOUR_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:5432/postgres
```

4. Paste both into **Render → Environment**
5. Also update local `backend/.env` to the same pooler URLs
6. **Manual Deploy** on Render
7. Recheck: https://visionaid-r29c.onrender.com/api/ready

You want:

```json
"checks": { "database": true, "auth": true }
```

## Quick check locally

```powershell
cd backend
node scripts/check-db.js
```

Should print `CONNECT_OK`.

## Fix for `no tenant identifier provided`

Pooler username must include project ref:

```text
postgres.fogmbmvvvzemdcyywsrd
```

**Wrong:** `postgres`  
**Right:** `postgres.YOUR_PROJECT_REF`

Example:

```text
DATABASE_URL=postgresql://postgres.fogmbmvvvzemdcyywsrd:PASSWORD@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
DIRECT_URL=postgresql://postgres.fogmbmvvvzemdcyywsrd:PASSWORD@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres
```

Copy these exact values into **Render → Environment**, then redeploy.
