# Database

**Source of truth for columns:** `backend/prisma/schema.prisma`

**SQL + RLS:** `supabase/migrations/20240822000000_init.sql`

```bash
cd backend
npx prisma db push
npx prisma generate
```

Or run the SQL file in the Supabase SQL editor.

## Tables

| Table | Purpose |
|-------|---------|
| profiles | Cloud user profile (id = auth.users.id when auth exists) |
| emergency_contacts | Named contacts + priority |
| favorite_objects | Personal object memory (cloud; local teaching not wired yet) |
| detection_history | Metadata only — no frames |
| voice_history | Command / intent / response metadata |
| locations | Saved places |
| settings | Voice + indoor/outdoor + sensitivity |
| orders | Demo food orders (unused) |

## RLS

Enabled on all listed tables.

Policy pattern: `auth.uid() = user_id` (profiles: `auth.uid() = id`).

Service-role (backend Prisma) bypasses RLS. Flutter must never ship the service-role key.

## App vs cloud

On-device `UserPrefs` currently holds language, name, and emergency contact. Cloud rows are for authenticated users in a later phase.
