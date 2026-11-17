# VoiceWeb Agent

**Final major-project build:** voice-first accessibility assistant that operates the web through a controlled browser.

- **ORION** (React Native / Expo): fully animated cosmic UI — splash, home, listen, process, confirm  
- Backend: Playwright + confirm-before-pay/send + Gemini + audit log  
- `flutter/` is legacy; use **`orion/`** as the mobile app  

## Docs

| Doc | Use |
|-----|-----|
| [docs/COMPLETE_PROJECT.md](docs/COMPLETE_PROJECT.md) | Full project document |
| [orion/README.md](orion/README.md) | ORION app run notes |

## Quick start

```powershell
cd backend
npm install
npm run install:browsers
npm run dev
```

```powershell
cd orion
npm start
```

In ORION **Settings**, set API URL to your PC (`http://<lan-ip>:8787` or emulator `http://10.0.2.2:8787`).

## Features shipped

1. Voice commands (EN + HI patterns)  
2. What’s on my screen?  
3. Live browser mirror  
4. Gmail open + unread digest  
5. WhatsApp Web open + draft send + confirm  
6. Swiggy / Flipkart prepare + confirm  
7. PDF / page summarize  
8. Emergency call  
9. Audit log at `/api/audit`  
