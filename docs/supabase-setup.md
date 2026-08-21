# Supabase setup (simple)

1. Create a project at [supabase.com](https://supabase.com/dashboard)
2. Put in `backend/.env`:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `DATABASE_URL` (pooler)
   - `DIRECT_URL` (direct)
3. Put in `flutter/dart_defines.json`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `API_BASE_URL`
4. Sync schema:

```bash
cd backend
npx prisma db push
npx prisma generate
```

5. Auth → Email → enable (disable “Confirm email” while testing)
