# VoiceWeb Agent — Complete Project Document

**Working title:** VoiceWeb Agent  
**One line:** A voice-first accessibility assistant that operates the real web (Gmail, WhatsApp Web, Swiggy, Flipkart Minutes) through a controlled browser, with human confirmation before send/pay.

**Rule:** This is the sole project under `vision aidd` — develop only here.

---

## 1. Problem & goal

Blind and low-vision users struggle with dense visual sites (inbox, chat lists, grocery grids). Native phone automation is brittle. VoiceWeb Agent puts a **simple voice UI on the phone** and a **Playwright browser on the PC** so the assistant can open, read, reply, and prepare cart actions the way a sighted person uses the web — with **confirm** before irreversible steps.

---

## 2. What ships (feature map)

| Area | Voice capabilities |
|------|--------------------|
| **Core** | Listen → intent → speak; continuous re-listen after each reply; Confirm / Cancel; Help; Time; Chat / jokes; Screen read; Page / PDF summarize |
| **Gmail** | Open; last mail; unread digest; tell me in brief; reply saying…; compose mail to…; open / search mail from…; confirm/cancel send |
| **WhatsApp** | Open; who messaged me (chat list); last unread / last from contact; brief; reply saying…; send to contact; confirm/cancel send |
| **Swiggy** | Order/search → prepare → confirm before place |
| **Flipkart Minutes** | HYPERLOCAL only (never Grocery); add item; brand missing → similar options; add option N; cart; remove; confirm opens cart (Add-to-cart still best-effort) |
| **Safety** | Confirm gate for send/pay; emergency SOS dial from Flutter; audit log |
| **UX** | EN + HI patterns; browser mirror screenshot; Settings (API URL, emergency contact) |

### Explicitly out of scope

- Live walking / YOLO vision  
- Play Store release  
- Silent auto-pay or auto-send without confirm  
- Controlling every native Android app  
- Full Flipkart Grocery / normal Flipkart marketplace  

---

## 3. Architecture

```
┌─────────────────────────────────────┐
│ Flutter Android app                 │
│  STT → POST /api/command → TTS      │
│  Continuous listen after speak      │
│  Browser mirror · PDF · SOS · Settings │
└──────────────────┬──────────────────┘
                   │ HTTP JSON
                   ▼
┌─────────────────────────────────────┐
│ Node.js Express (0.0.0.0:8787)      │
│  understandSpoken (Gemini + offline)│
│  dispatcher · memory · confirmGate  │
│  speakSanitize · audit              │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│ BrowserAgent (Playwright Chromium)  │
│  Persistent profile = stay logged in│
│  Connectors: gmail · whatsapp ·     │
│  swiggy · flipkart (Minutes only)   │
└─────────────────────────────────────┘
```

### Safety model

1. Automation **prepares** (open thread, draft message, search product).  
2. Sensitive steps enter **ConfirmGate**.  
3. User says **confirm** or **cancel** (cancel clears draft where possible).  
4. **Audit** records commands for viva evidence (`backend/data/audit.jsonl`).

### Context memory

Short-lived memory keeps `activeApp` (gmail / whatsapp / …) so “last message” after WhatsApp does not jump to Gmail. Reply flows reuse the last contact / mail when the user says “reply saying…”.

---

## 4. Repository layout

```
voiceweb-agent/
├── README.md
├── docs/
│   └── COMPLETE_PROJECT.md   ← this file
├── backend/
│   ├── package.json
│   ├── .env                  ← secrets (not committed)
│   ├── data/
│   │   ├── browser-profile/  ← Chromium login session
│   │   ├── audit.jsonl
│   │   └── last-screen.png
│   └── src/
│       ├── index.js
│       ├── config.js
│       ├── routes/api.js
│       ├── agent/
│       │   ├── understand.js   ← Gemini intent router
│       │   ├── dispatcher.js
│       │   ├── intent.js       ← offline regex + help
│       │   ├── memory.js
│       │   ├── confirmGate.js
│       │   ├── browserAgent.js
│       │   ├── gemini.js
│       │   └── speak.js
│       └── connectors/
│           ├── gmail.js
│           ├── whatsapp.js
│           ├── swiggy.js
│           └── flipkart.js     ← Minutes / HYPERLOCAL
└── flutter/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart           ← Listen-first UI
        ├── pages/settings_page.dart
        └── services/
            ├── api_client.dart
            └── prefs.dart
```

---

## 5. Voice intents (reference)

### Always available

| Intent | Example |
|--------|---------|
| `help` | help |
| `confirm` / `cancel` | confirm · cancel · yes · nahi |
| `time_now` | what is the time |
| `chat` | tell me a joke |
| `screen_read` | what’s on my screen |
| `summarize` / `pdf_summarize` | summarize · upload PDF then summarize |
| `followup_brief` | tell me in brief · more details |
| `live_sports` | cricket live score |
| `open_url` | open youtube |

### Gmail

| Intent | Example |
|--------|---------|
| `gmail_open` | open Gmail |
| `gmail_last` | what is the last mail |
| `gmail_unread` | any unread mail |
| `gmail_reply` | reply saying thanks I will check later |
| `gmail_compose` | compose mail to X saying hello |
| `gmail_search` | open mail from Google |

### WhatsApp

| Intent | Example |
|--------|---------|
| `whatsapp_open` | open WhatsApp |
| `whatsapp_chats` | who messaged me |
| `whatsapp_read` | last unread message · last message from mummy |
| `whatsapp_reply` | reply saying I will call you |
| `whatsapp_send` | send hello to Kshitiz |

### Commerce

| Intent | Example |
|--------|---------|
| `swiggy_order` | order Maggi on Swiggy |
| `flipkart_minutes` | add Nandini milk on Flipkart Minutes |
| `flipkart_minutes_alt` | add option 1 |
| `flipkart_minutes_cart` | open Minutes cart |
| `flipkart_minutes_remove` | remove milk from cart |

Routing prefers **Gemini + activeApp context**; tiny words (confirm/cancel/help) are offline; regex is fallback.

---

## 6. API surface

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Liveness + Gemini flag |
| GET | `/api/ready` | Browser + pending status |
| POST | `/api/browser/start` | Ensure Chromium |
| POST | `/api/command` | `{ "spoken": "…" }` → spoken reply + optional `pending` |
| GET | `/api/screenshot` | Latest browser mirror PNG |
| POST | `/api/pdf/summarize` | Upload + summarize |
| GET | `/api/audit` | Recent command evidence |

Default bind: **`0.0.0.0:8787`** (phone on same Wi‑Fi can reach PC IP).

---

## 7. Stack

| Layer | Tech |
|-------|------|
| Mobile | **ORION** React Native (Expo) + Reanimated — animated UI; talks to same backend. Legacy `flutter/` optional |
| Backend | Node 20+, Express, Playwright Chromium, Multer, pdf-parse |
| AI | Google Gemini (`GEMINI_API_KEY`, model e.g. `gemini-3.8-flash`); accepts `AIza…` or `AQ.…` keys |
| Browser | Persistent Chromium profile under `backend/data/browser-profile` |

---

## 8. Setup & run

### Backend

```powershell
cd "c:\Users\adity\vision aidd\voiceweb-agent\backend"
# .env: PORT=8787, GEMINI_API_KEY=…, GEMINI_MODEL=gemini-3.8-flash, HEADLESS=false
npm install
npm run install:browsers
npm run dev
```

Open http://127.0.0.1:8787 — status page.  
First run: log into **Gmail, WhatsApp Web, Swiggy, Flipkart Minutes** once in the Chromium window.

### Flutter (phone, same Wi‑Fi)

```powershell
cd "c:\Users\adity\vision aidd\voiceweb-agent\flutter"
flutter pub get
flutter run
```

Settings → API URL `http://<PC-LAN-IP>:8787` · set emergency number.  
Allow Windows firewall inbound **TCP 8787** if needed.

### Emulator

API URL: `http://10.0.2.2:8787`

---

## 9. Typical voice flows

### Mail (human-like)

1. *Open Gmail*  
2. *What is the last mail?* → short headline  
3. *Tell me in brief* → longer summary  
4. *Reply saying thanks, I will check later* → draft  
5. *Confirm* or *Cancel*

### WhatsApp (human-like)

1. *Open WhatsApp*  
2. *Who messaged me?* or *Last unread message*  
3. *Last message from mummy*  
4. *Reply saying I will call you in 10 minutes*  
5. *Confirm*

### Minutes (when enabled)

1. *Add Nandini milk on Flipkart Minutes*  
2. If brand missing → similar options spoken  
3. *Add option 1* → *Confirm* opens cart  

---

## 10. Demo script (≈5 minutes)

1. Listen → *What’s on my screen?*  
2. *Open Gmail* → *What is the last mail?* → *Tell me in brief*  
3. *Reply saying thanks* → show Confirm → *Cancel* (safe)  
4. *Open WhatsApp* → *Last unread message*  
5. Optional: *Order Maggi on Swiggy* → Confirm gate (do not place if not needed)  
6. SOS / emergency dial (settings number)  
7. Slide: architecture + confirm gate + limitations  

---

## 11. Honest limitations (viva)

- Sites change DOM; selectors are best-effort.  
- Login, OTP, captcha, and QR need the user once (then session persists).  
- Flipkart Minutes **Add** can be flaky; brand-miss + alternatives and cart read are stronger.  
- Not a replacement for TalkBack across all native apps.  
- Gemini improves routing/summaries; core confirm/cancel/help work offline.  
- Phone and PC must stay on the same network with backend running.

---

## 12. Environment variables

| Variable | Meaning |
|----------|---------|
| `PORT` | Default `8787` |
| `HOST` | Default `0.0.0.0` for LAN/phone |
| `GEMINI_API_KEY` | Google AI key (`AIza…` or `AQ.…`) |
| `GEMINI_MODEL` | e.g. `gemini-3.8-flash` |
| `BROWSER_USER_DATA_DIR` | Persistent profile path |
| `HEADLESS` | `false` for visible Chromium (recommended for demos) |

Never commit `.env` or `browser-profile` secrets.

---

## 13. Status snapshot (Nov 2026)


| Module | Status |
|--------|--------|
| Voice pipeline + continuous listen | Solid |
| Gmail read / brief / reply draft + confirm | Solid (smoke-tested) |
| WhatsApp open / read / reply / send confirm | Solid; chat-list depends on WA Web load |
| Intent routing with activeApp | Solid (Gemini-first) |
| Swiggy prepare + confirm | Demo-ready |
| Flipkart Minutes smart miss → alts | Working; Add-to-cart reliability still hardening |
| Emergency SOS | App-side dial |

---

*VoiceWeb Agent — major project build. Voice in, browser out, human confirm for send and pay.*
