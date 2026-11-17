# VoiceWeb Agent — Architecture

## Problem

Blind and low-vision users struggle with complex visual websites (Gmail, WhatsApp Web, food/grocery). Native phone automation is brittle. A **voice front-end + controlled browser backend** lets the assistant operate the web like a laptop, with **human confirmation** before payments/sends.

## System design

```
┌──────────────────────────┐
│ Flutter Android app      │
│  - STT / TTS (EN+HI)     │
│  - Command chips         │
│  - Browser mirror image  │
│  - PDF upload            │
│  - SOS dialer            │
│  - Settings (API, SOS)   │
└────────────┬─────────────┘
             │ HTTPS/HTTP JSON
             ▼
┌──────────────────────────┐
│ Node.js Express API      │
│  /api/command            │
│  /api/pdf/summarize      │
│  /api/screenshot         │
│  /api/audit (evidence)   │
└────────────┬─────────────┘
             │
     ┌───────┴────────┐
     ▼                ▼
 Intent router    Confirm gate
 (offline rules)  (pending pay/send)
     │
     ▼
 Playwright BrowserAgent
 (persistent Chromium profile)
     │
     ├── Gmail Web
     ├── WhatsApp Web
     ├── Swiggy
     └── Flipkart
             │
             ▼
        Gemini (optional)
        page/PDF summaries
```

## Safety model

1. AI / automation **prepares** actions (search, draft message, open cart).  
2. Sensitive steps enter **ConfirmGate**.  
3. User must say **confirm** (or Cancel).  
4. Audit log stores commands for viva evidence (`data/audit.jsonl`).

## Why this is valid research/engineering

- Separates **perception of UI** (browser DOM/text) from **mobile voice UX**.  
- Applies **human-in-the-loop** for irreversible actions.  
- Works **sideloaded** without Play Store; uses persistent browser login instead of fragile unofficial APIs where possible.

## Limitations

Website DOM changes; OTP/captchas need the user; Gemini improves summaries but core intents work offline; not a full native-app controller.
