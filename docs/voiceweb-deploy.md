# Deploy VoiceWeb Agent (visionaid GitHub → Render)

Backend lives at `backend/` in **kshitiz-12/visionaid**.

## Live URL

After deploy:

`https://voiceweb-agent.onrender.com`

Health: `https://voiceweb-agent.onrender.com/api/health`

## Deploy steps

1. Push `backend/` + `render.yaml` to GitHub `main`.
2. Render → Blueprint sync **or** Web Service:
   - Root Directory: `backend`
   - Dockerfile: `./Dockerfile`
   - Health: `/api/health`
3. Env (dashboard):
   - `HOST` = `0.0.0.0` (required for Render port scan)
   - `PORT` = `3000`
   - `GEMINI_API_KEY` = `AQ.…` or legacy `AIza…`
   - `GEMINI_MODEL` = `gemini-3.8-flash`
   - `HEADLESS` = `true`
   - `BROWSER_USER_DATA_DIR` = `/var/data/browser-profile`
4. Flutter Settings → API URL = Render URL (no trailing slash).

## If deploy times out on port scan

Service must listen on `0.0.0.0:$PORT`, not only `127.0.0.1`. Current `backend/src/index.js` does this.

## Honest limits (Render free)

- Cold starts ~30–60s.
- Chromium may OOM on heavy pages.
- Login cookies need the disk mount; for viva prefer laptop headed browser.
