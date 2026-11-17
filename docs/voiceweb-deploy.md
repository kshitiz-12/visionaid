# Deploy VoiceWeb Agent (same VisionAid GitHub repo → Render)

VoiceWeb lives at `voiceweb-backend/` inside the **visionaid** repo (`kshitiz-12/visionaid`).

## Live URL

After deploy, Render creates a service like:

`https://voiceweb-agent.onrender.com`

Health: `https://voiceweb-agent.onrender.com/api/health`

## Deploy steps

1. Push `voiceweb-backend/` + updated `render.yaml` to GitHub `main`.
2. Render Dashboard → sync Blueprint **or** New → Web Service:
   - Root Directory: `voiceweb-backend`
   - Dockerfile: `./Dockerfile`
   - Health: `/api/health`
3. Set env:
   - `GEMINI_API_KEY` = `AIza…` (required for good summaries)
   - `GEMINI_MODEL` = `gemini-2.5-flash`
   - `HEADLESS` = `true`
4. In the Flutter VoiceWeb app → Settings → API URL = the Render URL (no trailing slash).

## Honest limits on Render free

- Cold starts are slow (first request may take ~30–60s).
- Headless Chromium may OOM on free tier during heavy pages.
- Gmail/WhatsApp **login cookies** do not survive free ephemeral disks well — for the viva, prefer **local headed browser** (`npm run dev` on laptop) OR upgrade Render disk.
- Gemini summarize + intent routing + PDF API work fully live even if a site login fails.

## Recommended viva setup

| Piece | Where |
|-------|--------|
| Flutter APK | Phone |
| Browser automation (Gmail/WA/Swiggy) | Laptop `voiceweb-agent/backend` headed |
| OR API-only live | Render `voiceweb-agent` for health/PDF/Gemini |

For full browser wow in the panel room: run backend on the laptop, phone on same Wi‑Fi.  
For “we deployed on cloud”: show Render `/api/health` + PDF summarize live.
