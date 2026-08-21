# VisionAid++ setup checklist

## Done in the project

- [x] Flutter app shell (Riverpod, GoRouter, auth screens)
- [x] Supabase Auth integration (email/password)
- [x] Node backend on Render: https://visionaid-r29c.onrender.com
- [x] Health: `/api/health` working
- [x] Prisma schema + `db push` / `generate` workflow
- [x] Profile API (needs DB on Render — fix later)

## You do now (finish setup)

### 1. Flutter keys

```powershell
cd flutter
copy dart_defines.example.json dart_defines.json
```

Edit `dart_defines.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_REF.supabase.co",
  "SUPABASE_ANON_KEY": "your_anon_key",
  "API_BASE_URL": "https://visionaid-r29c.onrender.com"
}
```

### 2. Run the app

```powershell
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

### 3. Test auth

- Register → Sign out → Sign in
- Profile opens (may show “account info only” until Render DB is fixed)
- Reopen app → stays logged in

### 4. Later (not blocking auth)

Fix Render `DATABASE_URL` + `DIRECT_URL` so `/api/ready` shows `database: true`.

## Commands cheat sheet

```powershell
# Backend local
cd backend
npx prisma db push
npx prisma generate
npm run dev

# Flutter
cd flutter
flutter run --dart-define-from-file=dart_defines.json
```
