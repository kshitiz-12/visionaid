# VisionAid++ — Exact Product Flow

No login. No OTP.

## 1. First open — language

TTS: “Welcome to VisionAid. Which language do you prefer?”  
User picks **English** or **Hindi**.

## 2. Simple profile setup

- Name  
- Emergency contact phone  
Saved on device only.

## 3. Voice Home

A spoken companion. Ask questions, plan, call someone, or say **guide me**.

## 4. Speech → intent, then action

| Intent | What happens |
|--------|----------------|
| Conversation / help | Cloud companion answers in the user's language |
| Scene / find | Camera snapshot + companion (e.g. “where is my purse?”) |
| Navigation | Live camera walk / stop guide |
| OCR | Read print, then companion speaks it naturally |
| Call / SMS / WhatsApp | On-device contacts |
| Emergency | Call saved contact |
| Quit | Close the app |

## 5. Live camera (guide)

Say **guide me** or tap Look ahead. On-device stream. Speaks **stop / wait / what is close**, with a cooldown.

## 6. Context engine

Ranks detections by confidence, proximity, motion, intent, importance, navigation risk. Speaks hazards and matches, not every object.

## 7. Voice

If `OPENAI_API_KEY` is set on the backend, replies play with **OpenAI TTS**. Otherwise the device voice is used.

Cloud keys stay on the server. The app sends **text** and short on-device scene facts, not a live video feed.

**Calls / SMS / WhatsApp:** *Call Harry*, *Text Harry*, or *WhatsApp Harry saying I’m late*.  
**Stay on screen:** Back does not quit. Say **quit**. Home still leaves the app (not a kiosk).

## Try it

```bash
cd flutter
flutter run
```

Set `OPENAI_API_KEY` (or `GEMINI_API_KEY`) on the Node server / Render, then ask a question, say **where is my purse**, or **guide me**.
