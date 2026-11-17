# ORION — React Native (Expo)

Fully animated dark/cosmic UI for VoiceWeb Agent. **Same backend** as before (`:8787`).

## Why React Native

Flutter was fine for a simple listen button. This ORION UI needs continuous ring spin, glow pulse, waveforms, and glass cards — **Reanimated** fits that better. Decision: **RN is the mobile UI now**; Flutter app can stay archived unused.

## Run

```powershell
# terminal 1 — backend
cd ..\backend
npm run dev

# terminal 2 — ORION
cd ..\orion
npm start
```

Scan QR with Expo Go, or `a` for Android emulator.

**Settings → API URL**
- Emulator: `http://10.0.2.2:8787`
- Real phone: `http://<your-pc-lan-ip>:8787`

## Screens

1. Splash (black hole + load bar)  
2. Onboarding (Meet ORION)  
3. Home (Tap to Talk + quick commands)  
4. Listening (orb + waveform)  
5. Processing (step checklist)  
6. Action / confirm (WhatsApp-style send card)

## Voice note

Expo Go has no full on-device STT plugin in this build. Listening screen accepts **typed commands** (keyboard). TTS uses `expo-speech`. Native mic STT can be added later with a development build + `@react-native-voice/voice`.
