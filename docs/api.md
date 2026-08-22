# VisionAid++ API Contract

Base URL: `http://127.0.0.1:3000` (development)

All responses follow:

```json
{
  "success": true,
  "message": "Human-readable message",
  "data": {},
  "error": null
}
```

## Authentication

Flutter onboarding is **voice + on-device prefs** (no OTP in the current app).

When a Supabase session exists, protected backend routes require:

```
Authorization: Bearer <supabase_access_token>
```

The Node.js backend verifies tokens via `supabase.auth.getUser(token)`.

There are **no** custom `/auth/login` Node endpoints. Phone OTP is a future auth phase.

## Health

### GET /api/health

Public endpoint. No authentication required.

**Response 200**

```json
{
  "success": true,
  "message": "VisionAid++ backend is healthy",
  "data": {
    "status": "ok",
    "service": "visionaid-backend",
    "timestamp": "2025-08-21T12:00:00.000Z"
  },
  "error": null
}
```

### GET /api/ready

Readiness probe. Returns 200 when database and auth config are available; otherwise 503.

**Response 200**

```json
{
  "success": true,
  "message": "VisionAid++ backend is ready",
  "data": {
    "status": "ready",
    "checks": { "database": true, "auth": true },
    "timestamp": "2025-08-21T12:00:00.000Z"
  },
  "error": null
}
```

## Companion (public, rate-limited)

Requires `OPENAI_API_KEY` and/or `GEMINI_API_KEY` on the server. OpenAI is used first when both are set. Natural voice (`POST /speak`) needs OpenAI.

### GET /api/assistant/status

```json
{ "data": { "chat": true, "naturalVoice": true } }
```

### POST /api/assistant/chat

```json
{
  "message": "What should I cook tonight?",
  "language": "en",
  "userName": "Aditya",
  "sceneSummary": "Stop. Person is nearby.",
  "history": [{ "role": "user", "content": "Hi" }, { "role": "assistant", "content": "Hey." }]
}
```

### POST /api/assistant/speak

JSON `{ "text": "...", "language": "hi" }` → `audio/mpeg`.

## Profile

### GET /api/profile

Requires Supabase JWT.

Returns the authenticated user's profile from the `profiles` table.

### PATCH /api/profile

Requires Supabase JWT.

**Body**

```json
{
  "full_name": "Updated Name",
  "email": "user@example.com"
}
```

## Planned endpoints (not yet implemented)

| Method | Path | Purpose |
|--------|------|---------|
| POST | /api/scene | (optional) extra vision — companion uses scene facts instead |
| POST | /api/context | Context engine scoring |
| GET | /api/history/detections | Detection history |
| GET | /api/history/voice | Voice command history |
| POST | /api/emergency | Emergency alert orchestration |

## Error codes

| Code | HTTP | Description |
|------|------|-------------|
| UNAUTHORIZED | 401 | Missing Bearer token |
| INVALID_TOKEN | 401 | Expired or invalid Supabase JWT |
| RATE_LIMIT_EXCEEDED | 429 | Too many requests |
| SERVICE_UNAVAILABLE | 503 | Supabase not configured on server |

## Security

- Supabase JWT verification on protected routes
- Prisma ORM for server-side PostgreSQL access (same Supabase DB)
- Rate limiting (200 requests / 15 min per IP)
- Request logging (method, path, status, duration)
- No raw camera frames in API requests
- Service-role key never exposed to clients

## Privacy

- Do not log passwords, access tokens, or sensitive images
- Prefer on-device processing; cloud endpoints are opt-in
