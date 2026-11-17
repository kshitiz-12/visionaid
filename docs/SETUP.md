# Setup (final review machine)

## Prerequisites

- Node.js 20+
- Flutter 3.9+
- Android phone or emulator
- Google AI Studio key starting with **`AIza`** (recommended)

## Backend

```powershell
cd "c:\Users\adity\vision aidd\voiceweb-agent\backend"
copy .env.example .env
# Edit .env → GEMINI_API_KEY=AIza...
npm install
npm run install:browsers
npm run dev
```

Open http://127.0.0.1:8787 — should show status page.

First run: Chromium window opens. **Log into** Gmail, WhatsApp Web, Swiggy, Flipkart once. Session persists in `data/browser-profile`.

## Flutter

```powershell
cd "c:\Users\adity\vision aidd\voiceweb-agent\flutter"
flutter pub get
```

### Emulator

```powershell
flutter run
```

Default API: `http://10.0.2.2:8787` (editable in Settings).

### Real phone (same Wi‑Fi)

1. Find PC IP (`ipconfig`)  
2. App → Settings → API URL `http://192.168.x.x:8787`  
3. Set emergency phone  
4. `flutter run` (or install APK)

```powershell
flutter build apk --release
```

APK: `flutter/build/app/outputs/flutter-apk/app-release.apk`

## Firewall

Allow inbound TCP **8787** on the PC if the phone cannot connect.
