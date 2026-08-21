# VisionAid++

VisionAid++ is an AI-powered, voice-first vision assistant for visually impaired users. It prioritizes accessible interaction, on-device inference for privacy-sensitive workloads, and a context-aware decision engine that limits spoken output to the highest-priority information.

## Architecture summary

- **Flutter** mobile app with feature-first Clean Architecture
- **Riverpod** state management and **GoRouter** for navigation
- **Supabase** for authentication, PostgreSQL database, storage, and Row Level Security
- **Prisma** ORM in the Node.js backend for server-side PostgreSQL access
- **Node.js + Express** backend for AI orchestration, Gemini API, and secure server-side operations
- **YOLOv8 Nano + TensorFlow Lite** on-device for object detection (planned)
- **Google ML Kit OCR** for offline text extraction (planned)
- **Google Maps + ARCore** for navigation and depth-aware alerts (planned)
- **Gemini API** only for advanced scene understanding (optional, graceful degradation)

## Directory structure

```
VisionAid/
├── flutter/          # Mobile application (Dart / Flutter)
├── backend/          # Node.js API for AI orchestration
├── supabase/         # PostgreSQL migrations, RLS, local config
└── docs/             # Architecture and API documentation
```

## Prerequisites

- Flutter SDK 3.9+
- Node.js 20+
- Supabase project (cloud or local CLI)

## Quick start

### 1. Supabase

Create a Supabase project and apply migrations:

```bash
supabase db push
```

Or run migration SQL manually from `supabase/migrations/`.

### 2. Backend

```bash
cd backend
cp .env.example .env
npm install          # runs prisma generate via postinstall
npm run dev
```

Health check: `GET http://127.0.0.1:3000/api/health`  
Readiness: `GET http://127.0.0.1:3000/api/ready`

### 3. Flutter

```bash
cd flutter
copy dart_defines.example.json dart_defines.json
# edit dart_defines.json with SUPABASE_URL + anon key
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

Full walkthrough: [docs/supabase-setup.md](docs/supabase-setup.md)

### 4. Deploy backend (Render)

See [docs/deploy.md](docs/deploy.md). Summary:

1. Push repo to GitHub
2. Render → Blueprint (uses `render.yaml`) or Web Service with root `backend`
3. Paste Supabase URL, service-role key, `DATABASE_URL`, `DIRECT_URL` in Render env
4. Confirm `https://YOUR-SERVICE.onrender.com/api/health` and `/api/ready`
5. Set Flutter `API_BASE_URL` to that Render URL

## Core product principle

The research contribution is the **Adaptive Context-Aware Decision Engine** — it scores detections by confidence, distance, motion, user intent, object importance, and navigation risk before speaking, reducing cognitive overload.

## Security notes

- Never expose the Supabase **service-role key** in Flutter
- Flutter uses only the Supabase **anon/public key**
- Camera frames stay on device by default
- Node.js verifies Supabase JWTs on protected API routes
- Production requires `DATABASE_URL`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`

## Production checklist

- [ ] Set `NODE_ENV=production` on the backend host
- [ ] Fill `DATABASE_URL`, `DIRECT_URL`, Supabase keys, and `CORS_ORIGINS`
- [ ] Apply all SQL under `supabase/migrations/` (including FORCE RLS)
- [ ] Flutter release build uses real `SUPABASE_URL` / `SUPABASE_ANON_KEY` and `DEBUG_MODE=false`
- [ ] Verify `GET /api/health` and `GET /api/ready`
- [ ] Confirm email auth settings (enable confirmations in production)
- [ ] Deploy backend (e.g. Render) with health check path `/api/health`

## Git strategy

- `main` — production-ready releases
- `develop` — integration branch
- `feature/*` — feature branches (auth, vision, ocr, navigation, context, emergency)

## Status

Foundation setup complete: Supabase schema, RLS, Flutter shell, Node.js health API, and documentation scaffolding are in place.
