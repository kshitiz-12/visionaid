# Database (simple)

Schema lives in `backend/prisma/schema.prisma`.

```bash
cd backend
npx prisma db push
npx prisma generate
```

Supabase hosts Postgres + Auth. No separate SQL migration folder.
