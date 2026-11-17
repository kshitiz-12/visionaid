# VoiceWeb Agent

Voice-first browser assistant: Flutter STT/TTS + Node/Express + Playwright Chromium. Confirms risky actions before click; Gemini summarizes pages and PDFs.

## Layout

```
visionaid/
├── flutter/     # Android voice client
├── backend/     # Playwright agent API (Render)
├── docs/        # Architecture, setup, demo, report
└── render.yaml  # Render Blueprint
```

## Backend (local)

```bash
cd backend
copy .env.example .env
# set GEMINI_API_KEY=AIza...
npm install
npx playwright install chromium
npm run dev
```

Health: `GET http://127.0.0.1:8787/api/health`

## Flutter

```bash
cd flutter
flutter pub get
flutter run
```

In **Settings**, set API base URL to your machine IP (`http://192.168.x.x:8787`) or the Render URL after deploy.

## Deploy (Render)

1. Push this repo to GitHub.
2. Render → New → Blueprint → select the repo.
3. Set `GEMINI_API_KEY` (must start with `AIza`).
4. After deploy, point the Flutter app at `https://<service>.onrender.com`.

Details: [docs/voiceweb-deploy.md](docs/voiceweb-deploy.md) · [docs/SETUP.md](docs/SETUP.md)
