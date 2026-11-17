# VoiceWeb Agent — Major Project (LOCKED)

**Working title:** VoiceWeb Agent  
**One line:** A voice-first accessibility assistant that operates the web through a controlled browser (Gmail, WhatsApp Web, Swiggy, Flipkart Minutes), with human confirmation before payments.

**Rule:** Do **not** modify `autonomous-automation`, `orchestration`, or `whatsapp automation`. This repo is standalone.

---

## Locked demo features (must show)

| # | Feature | How |
|---|---------|-----|
| 1 | Voice command → action | Flutter STT → backend agent |
| 2 | What’s on my screen? | Playwright reads page text → TTS |
| 3 | Browser mirror | Latest screenshot in the app |
| 4 | Gmail (web) | Open / read unread summary |
| 5 | WhatsApp Web | Open chat / send with confirm |
| 6 | Swiggy / Flipkart Minutes | Search → cart → **confirm before place** |
| 7 | PDF / page summary | Gemini summarize |
| 8 | Emergency call | Dial saved contact from app |
| 9 | Hindi + English | Same commands both languages |

## Explicitly out of scope

- Live YOLO / walking vision  
- Play Store release  
- Silent auto-pay without “confirm”  
- Controlling every native Android app  

---

## Architecture

```
Flutter (voice + mirror + SOS)
        │ HTTP
        ▼
Node API (Express)
        │
        ├─ Intent parse (rules + optional Gemini)
        ├─ BrowserAgent (Playwright, persistent profile)
        ├─ Connectors: gmail / whatsapp / swiggy / flipkart
        └─ Confirm gate (pending actions until user says confirm)
```

## 5-minute viva demo script

1. Open app → “Listen” → “What’s on my screen?”  
2. “Open Gmail” → “Any new mail?” → hear summary  
3. “Order Maggi on Swiggy” → hear cart → “Confirm”  
4. “Call emergency” / saved contact  
5. Show architecture diagram + limitations slide  

## Honest limitations (say this in viva)

Sites change; login/OTP/captcha need the user; grocery/food flows are best-effort automation with confirmation; not a replacement for TalkBack for all apps.

## Stack

- Flutter 3.9+ (Android sideload APK)  
- Node 20+ / Express / Playwright  
- Google Gemini (optional; rules work offline for core intents)  
