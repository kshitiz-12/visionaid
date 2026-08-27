# VisionAid++ Architecture

## Design principles

1. **Voice-first** — a completely blind user living alone must complete core tasks without seeing the screen.
2. **Feature-first Clean Architecture** — `data` / `domain` / `presentation` per feature; Riverpod injection.
3. **On-device by default** — camera frames stay on the phone unless the user opts into cloud AI.
4. **Adaptive Context Engine** — do not speak every detection; rank by risk, intent, and cooldown.
5. **Independent-living fallbacks** — if internet, Gemini, or cloud auth fail, local voice + vision + emergency contact still work.

## Current product (honest)

The mobile app is **login-free** today: language → voice profile (name + emergency contact on device) → Voice Home.

**Phone OTP / persistent Supabase sessions** are specified for a later auth phase. They are **not** implemented in Flutter yet. Cloud tables + RLS exist for when that phase ships.

## System layers

```
Flutter (voice, camera, ML Kit, Context Engine, local prefs)
    │ optional HTTP + JWT          │ optional anon SDK
    ▼                              ▼
Node.js Express (helmet, CORS,     Supabase Postgres + Auth
rate limit, Prisma, /api/health)   RLS: auth.uid() = user_id
```

## Detection pipeline (implemented)

```
Speech → Intent Engine → live camera stream
  → ML Kit objects + image labels (YOLO TFLite swappable, not bundled)
  → Context Engine (priority + speak gate)
  → TTS (hazards / named objects / scene change only)
```

OCR (`Read this`) uses a still frame + ML Kit Text Recognition.

Gemini continuous walking, ARCore live depth, food ordering, and persistent spatial maps are **not** implemented. Outdoor turn-by-turn uses **Geoapify** when `GEOAPIFY_API_KEY` is set.

## Flutter

| Layer | Role |
|-------|------|
| presentation | Pages (voice home, live vision, settings, onboarding) |
| domain | Intent, context, OCR, vision contracts |
| data | ML Kit, STT/TTS, emergency caller |
| core | Config, router, theme, pipeline |

## Backend

| Layer | Role |
|-------|------|
| `GET /api/health` | Liveness |
| `GET /api/ready` | DB + auth config |
| `/api/profile` | JWT-protected upsert (unused by guest app) |
| Prisma | Same Postgres as Supabase |

## Deployment

Render for Node. Supabase Cloud for Postgres.
