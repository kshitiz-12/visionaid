# VisionAid++

VisionAid++ is an AI-powered, voice-first vision assistant for visually impaired users. It prioritizes accessible interaction, on-device inference for privacy-sensitive workloads, and a context-aware decision engine that limits spoken output to the highest-priority information.

## Architecture summary

- **Flutter** mobile app with feature-first Clean Architecture
- **Riverpod** state management and **GoRouter** for navigation
- **No login** — language + on-device profile, then voice home
- **Supabase** Postgres (backend/Prisma); Flutter uses anon key only if cloud features are enabled
- **Prisma** ORM in the Node.js backend for server-side PostgreSQL access
- **Node.js + Express** backend for health, profiles, and optional AI orchestration
- **On-device vision** via ML Kit Object Detection (YOLO TFLite-swappable)
- **On-device OCR** via Google ML Kit Text Recognition
- **Context Engine** ranks and filters what to speak
- **Emergency** opens dialer/SMS to the saved contact
- **Gemini API** only for advanced scene understanding (optional, graceful degradation)

## Directory structure

```
VisionAid/
├── flutter/          # Mobile app
├── backend/          # Node API + Prisma
├── supabase/         # SQL migrations + RLS
└── docs/
```

## Prerequisites

- Flutter SDK 3.9+
- Node.js 20+
- Supabase project

## Quick start

### 1. Database

```bash
cd backend
copy .env.example .env
# fill SUPABASE_URL, SERVICE_ROLE_KEY, DATABASE_URL, DIRECT_URL
npm install
npx prisma db push
npx prisma generate
```

Full steps: [docs/supabase-setup.md](docs/supabase-setup.md)

### 2. Backend

```bash
npm run dev
```

- Health: `GET http://127.0.0.1:3000/api/health`
- Ready: `GET http://127.0.0.1:3000/api/ready`

### 3. Flutter

```bash
cd flutter
copy .env.example .env
# fill SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL in .env
flutter pub get
flutter run
flutter build apk --release
```

Exact voice pipeline: [docs/product-flow.md](docs/product-flow.md)

### 4. Deploy backend (Render)

See [docs/deploy.md](docs/deploy.md).
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
- [ ] Fill `DATABASE_URL`, `DIRECT_URL`, Supabase keys
- [ ] `npx prisma db push` + `npx prisma generate`
- [ ] Flutter uses real `SUPABASE_URL` / `SUPABASE_ANON_KEY`
- [ ] Verify `GET /api/health` and `GET /api/ready`
- [ ] Deploy backend (Render) with health check `/api/health`

## Git strategy

- `main` — production-ready releases
- `develop` — integration branch
- `feature/*` — feature branches (auth, vision, ocr, navigation, context, emergency)

## Status

**Foundation + early product loop exist.** Guest voice onboarding, live vision, OCR, context filtering, and emergency call are in Flutter. Cloud **phone OTP is not built**. Schema/RLS live in Prisma + `supabase/migrations/`.
