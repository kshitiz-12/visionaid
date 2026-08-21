# Fix Supabase (app + backend)

## Flutter (simple `.env`)

```powershell
cd flutter
copy .env.example .env
```

Put your keys in `flutter/.env`, then:

```powershell
flutter run
flutter build apk --release
```

## Backend (Render + local)

1. Supabase → Database → connection strings  
2. Paste `DATABASE_URL` (6543 pooler) + `DIRECT_URL` (5432) into `backend/.env` and Render Environment  
3. `node scripts/check-db.js` → `CONNECT_OK`  
4. https://visionaid-r29c.onrender.com/api/ready → `database: true`
