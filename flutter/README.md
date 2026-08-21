# VisionAid++ Flutter App

Voice-first mobile client for VisionAid++.

## Setup

```bash
cd flutter
flutter pub get
```

Copy `flutter/.env.example` values into dart-defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

For release builds set `DEBUG_MODE=false` and always provide Supabase keys.

## Architecture

- Clean Architecture feature folders
- Riverpod for state
- GoRouter with auth redirects
- Supabase Auth (email/password)
- Backend API calls send Supabase JWT via `ApiClient`

## Commands

```bash
flutter analyze
flutter test
flutter run
```
