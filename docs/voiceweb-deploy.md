# Deploy VoiceWeb Agent (visionaid GitHub → Render)

Backend lives at `backend/` in **kshitiz-12/visionaid**.

## Live URL

After deploy:

`https://voiceweb-agent.onrender.com`

Health: `https://voiceweb-agent.onrender.com/api/health`

## Deploy steps

1. Push `backend/` + `render.yaml` to GitHub `main`.
2. Render → Blueprint sync **or** New → Web Service:
   - Root Directory: `backend`
   - Dockerfile: `./Dockerfile`
   - Health: `/api/health`
3. Env:
   - `GEMINI_API_KEY` = `AIza…`
   - `GEMINI_MODEL` = `gemini-2.5-flash`
   - `HEADLESS` = `true`
   - `BROWSER_USER_DATA_DIR` = `/var/data/browser-profile`
4. Flutter Settings → API URL = Render URL (no trailing slash).

## Honest limits (Render free)

- Cold starts ~30–60s.
- Chromium may OOM on heavy pages.
- Login cookies need persistent disk; for viva prefer laptop headed browser for Gmail/WA.

## Viva setup

| Piece | Where |
|-------|--------|
| Flutter APK | Phone |
| Full browser demos | Laptop `backend` headed |
| Cloud proof | Render `/api/health` + PDF summarize |
