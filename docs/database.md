# VisionAid++ Database Schema

VisionAid++ uses **Supabase PostgreSQL** as the primary data store. All user-owned tables enforce **Row Level Security (RLS)** so users can only access their own records (`auth.uid() = user_id`).

**Schema migrations** are managed in `supabase/migrations/`.

The **Node.js backend** uses **Prisma** (`backend/prisma/schema.prisma`) as the ORM to query the same database. Prisma does not replace Supabase Auth or RLS for client access — Flutter continues to use the Supabase SDK directly.

## Tables

### profiles

Extends Supabase `auth.users`.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | References `auth.users(id)` |
| full_name | TEXT | |
| email | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

Auto-created via trigger on user signup.

### emergency_contacts

| Column | Type |
|--------|------|
| id | UUID PK |
| user_id | UUID FK → profiles |
| name | TEXT |
| phone | TEXT |
| relationship | TEXT |
| created_at | TIMESTAMPTZ |

### favorite_objects

| Column | Type |
|--------|------|
| id | UUID PK |
| user_id | UUID FK → profiles |
| object_name | TEXT |
| description | TEXT |
| embedding | VECTOR(512) |
| created_at / updated_at | TIMESTAMPTZ |

Uses the `pgvector` extension for similarity search (future).

### detection_history

Stores on-device detection summaries (not raw images).

| Column | Type |
|--------|------|
| id | UUID PK |
| user_id | UUID FK |
| object_name | TEXT |
| confidence | REAL |
| distance | REAL |
| risk_score | REAL |
| detected_at | TIMESTAMPTZ |

### voice_history

| Column | Type |
|--------|------|
| id | UUID PK |
| user_id | UUID FK |
| command | TEXT |
| intent | TEXT |
| response | TEXT |
| created_at | TIMESTAMPTZ |

### locations

Saved places for navigation memory.

| Column | Type |
|--------|------|
| id | UUID PK |
| user_id | UUID FK |
| name | TEXT |
| latitude | DOUBLE PRECISION |
| longitude | DOUBLE PRECISION |
| created_at | TIMESTAMPTZ |

### settings

One row per user (unique `user_id`).

| Column | Type | Default |
|--------|------|---------|
| indoor_mode | BOOLEAN | false |
| outdoor_mode | BOOLEAN | true |
| voice_speed | REAL | 1.0 |
| voice_volume | REAL | 1.0 |
| alert_distance | REAL | 3.0 |

Auto-created on signup alongside profile.

### orders

| Column | Type |
|--------|------|
| id | UUID PK |
| user_id | UUID FK |
| restaurant_name | TEXT |
| items | JSONB |
| total_amount | NUMERIC(10,2) |
| status | TEXT |
| created_at | TIMESTAMPTZ |

## Row Level Security

RLS is **enabled and forced** on all tables above (`FORCE ROW LEVEL SECURITY`). Policies follow this pattern:

- **SELECT** — `auth.uid() = user_id` (or `id` for profiles)
- **INSERT** — `WITH CHECK (auth.uid() = user_id)`
- **UPDATE** — `USING` + `WITH CHECK` on `user_id`
- **DELETE** — `auth.uid() = user_id`

Never disable RLS in production.

## Signup trigger

`handle_new_user()` runs after insert on `auth.users`:

1. Creates a `profiles` row
2. Creates default `settings` row

## Storage buckets (future)

Possible buckets when needed:

- `user-objects`
- `profile-images`
- `research-data`

Camera frames are **not** uploaded by default.

## Prisma (backend)

The Node.js backend uses Prisma to access PostgreSQL:

```bash
cd backend
npm run db:generate   # regenerate client after schema changes
npm run db:studio     # open Prisma Studio (requires DATABASE_URL)
npm run db:pull       # introspect DB into schema (optional)
```

Connection strings are in `backend/.env.example`:

- `DATABASE_URL` — pooled connection for runtime
- `DIRECT_URL` — direct connection for Prisma CLI

**Important:** Prisma connects with a privileged database role. Client-facing access still goes through Supabase Auth + RLS. Backend repositories must always scope queries by `req.user.id` from the verified JWT — never trust client-supplied user IDs.

## Applying migrations

```bash
# With Supabase CLI linked to your project
supabase db push

# Or apply SQL files manually in the Supabase SQL editor
```

## Local development

```bash
supabase start
supabase db reset   # applies migrations + seed.sql
```
