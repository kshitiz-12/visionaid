# VisionAid++ setup

## Flutter (simple)

1. One-time: copy env file and put your keys

```powershell
cd flutter
copy .env.example .env
```

Edit `flutter/.env`:

```env
SUPABASE_URL=https://YOUR_REF.supabase.co
SUPABASE_ANON_KEY=your_anon_public_key
API_BASE_URL=https://visionaid-r29c.onrender.com
```

2. Run / build — **no dart-defines**

```powershell
flutter run
flutter build apk --release
```

## App flow

Language → name + emergency contact → Voice Home

## Backend Supabase

See [supabase-setup.md](supabase-setup.md). Paste `DATABASE_URL` on Render, then check `/api/ready`.
