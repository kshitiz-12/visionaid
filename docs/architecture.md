# VisionAid++ Architecture

## Design principles

### 1. Feature-first Clean Architecture

The codebase is split into feature modules. Each feature contains layered responsibilities:

- **data** — repositories, services, models, DTOs
- **domain** — entities, repository contracts, business rules
- **presentation** — pages, widgets, Riverpod providers

This keeps business logic isolated from UI and infrastructure.

### 2. Dependency inversion

Upper layers depend on abstractions. Repositories are interfaces in the domain layer; concrete implementations live in the data layer and are injected via Riverpod providers.

### 3. Supabase as primary backend platform

Supabase handles:

- Authentication (email/password initially)
- PostgreSQL database with Row Level Security
- Storage for user-specific files when needed

The Node.js backend is **not** the primary database layer for the mobile client. It uses **Prisma** as the ORM to access the same Supabase PostgreSQL database for server-side operations (AI orchestration, complex queries, admin tasks). **Supabase Auth** remains the identity provider; JWTs are verified on protected routes.

### 4. Voice-first interaction model

Voice is the primary mode of interaction. Major flows must remain accessible without visual input.

### 5. Privacy-first inference

Object detection and OCR run on-device. Camera frames are not uploaded by default. Cloud processing (Gemini) is opt-in and clearly separated from local inference.

### 6. Adaptive context-aware prioritization

The Context Engine (future phase) filters detected objects by priority score before speaking. This is the product's research contribution.

## System layers

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter (Mobile)                      │
│  presentation → domain → data → core                    │
│  On-device: YOLO, ML Kit OCR, STT, TTS                   │
└───────────────┬─────────────────────┬───────────────────┘
                │ Supabase SDK        │ HTTP (JWT)
                ▼                     ▼
┌───────────────────────┐   ┌─────────────────────────────┐
│       Supabase        │   │   Node.js + Express         │
│  Auth / Postgres /    │   │   AI orchestration, Gemini  │
│  Storage / RLS        │   │   JWT verification          │
└───────────────────────┘   └─────────────────────────────┘
```

## Flutter layer

| Layer | Responsibility |
|-------|----------------|
| presentation | Pages, widgets, providers |
| domain | Entities, repository contracts |
| data | Supabase/API implementations |
| core | Config, services, theme, utils |

## Backend layer

| Layer | Responsibility |
|-------|----------------|
| routes | HTTP endpoint definitions |
| controllers | Request/response handling |
| services | Business logic |
| repositories | Prisma data access (PostgreSQL) |
| middlewares | Auth, logging, rate limiting, errors |
| ai | Vision, OCR, context, Gemini modules (future) |

## Detection pipeline (planned)

```
Camera → YOLO → Object Detection → Context Engine → Risk Calculation → Priority Ranking → Voice Response
```

## Deployment

Initial deployment target: **Render** for the Node.js backend. Supabase is hosted on Supabase Cloud.
