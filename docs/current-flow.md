# VisionAid++ — current flow and how it works

Honest snapshot of the **cleaned MVP** (identify + commands + last-seen memory).  
No login. English or Hindi. Name and emergency contact stay on the phone.

---

## 1. App start

```
Language → Setup (name + emergency contact) → Voice Home
```

- Profile is **on-device** (SharedPreferences).
- Camera frames stay on the phone by default.
- Optional cloud: Gemini (chat / hard Q&A), Render companion, Geoapify (outdoor routes).
- Core actions work **offline**: find, look ahead, call, emergency, quit.

---

## 2. Voice Home (main screen)

Stay here for talk, call, find, and questions. Open **Look ahead** only when you want the live camera.

### Gestures

| Gesture | Action |
|---------|--------|
| **1 tap** anywhere | Listen (same as mic) |
| **2 taps** | Open Look ahead (`/live`) |
| **3 taps** | Emergency call |
| **Two fingers down** | Quit app |

TalkBack’s double-tap can fight these gestures — turn TalkBack off while testing, or use the labelled buttons.

### Command routing (important)

Speech is classified by the **offline intent engine first**. These never get stolen by Gemini chat:

| You say | What happens |
|---------|----------------|
| “Find my bottle” / “Where is the chair” | Speak **last-seen memory** (if any) → open live find |
| “Guide me” / “Look ahead” | Open live walk mode |
| “What do you see?” / “What’s around me?” / “Ye kya hai?” | Open Look ahead (names nearby + remembers them) |
| “Call Mom” / “Text Dad …” / WhatsApp | Phone contacts / messaging. If several matches: speak up to 3 options, auto-listen for **1 / 2 / 3** (no “Okay” ack). Strong single match dials immediately. |
| “Emergency” / “Call me” | Saved emergency number (SMS fallback with location) |
| “Read this” | Still photo + on-device OCR → speak |
| “Navigate to the park” | Outdoor route (needs `GEOAPIFY_API_KEY`) |
| “Quit” / “Quiet” | Close app |

Everything else (jokes, “what is aalu in English?”, open chat) goes to **Gemini / companion** when configured.

```
Mic / 1 tap
    → STT
    → IntentEngine (offline rules)
         ├─ find / look ahead / call / emergency / read / scene
         │      → local handler (no Gemini required)
         └─ conversation / unknown
                → Gemini agent (if key set) or companion chat
```

---

## 3. Look ahead (live walk)

**Route:** `/live` (no target)

Hold phone **chest-high, camera forward**, walk slowly.

### What it does

1. **YOLO** streams object boxes (on-device).
2. Periodic **ML Kit** boxes + image labels enrich names (for memory + hazard matching).
3. **Free-space + guide** decide if the walking corridor is clear.
4. **If blocked:** short steer only, e.g. “Chair. Move right.” / “Move left.” / “Stop.” — not looping “X ahead about 1 metre.” Re-speaks only when direction changes or after ~12s.
5. **If clear:** “Path clear. You can walk forward.” (rarely; after a block clears).
6. **Silent memory** still logs stable detections to SQLite (does not speak every insert).
7. Beep / vibration when something is very close (~1 m).

### Controls on this screen

| Action | Result |
|--------|--------|
| **Double tap** | Go home |
| **Triple tap** | Emergency |
| **Stop looking** button | Go home |
| Two fingers down | Quit |

There is **no continuous voice mic** on this screen (it fought TTS). Give find/chat commands from **Home**.

### Honest limits

- Names common indoor objects when confident; otherwise shape cues (“nearby thing”).
- Does **not** reliably name food or tiny clutter.
- Distances are approximate.

---

## 4. Find mode (live search)

**Route:** `/live?target=bottle` (example)

Triggered by: “Find my …”, “Where is …”, or Home after a last-seen hint.

### Flow

```
Home: “Find bottle”
    → open SpatialDb / MemoryTracker
    → if last seen: speak “I last saw your bottle to your left, about 2 metres away, near living room, 1 minute ago. Looking again now.”
    → if never seen: “No memory of bottle yet. Looking now.”
    → /live?target=bottle
         → camera + YOLO + ML Kit
         → haptic / beep geiger as you center on match
         → speak when found
         → save sighting to memory immediately
```

Only the **target** (and crash-range safety) is spoken — not full room chatter.

---

## 5. Last-seen memory (how remembering works)

| Piece | Role |
|-------|------|
| `SpatialDb` (SQLite) | Persists nodes + `object_memory` rows across app restarts |
| `MemoryTracker` | Silent logger while looking; recall helper for find |
| Live Look ahead / Find | Feeds detections when confidence is stable |

Each memory row roughly stores:

- object label (canonical, synonym-aware: purse ↔ bag, shoes ↔ footwear…)
- associated place node (default: “living room” until places are taught)
- relative direction (left / ahead / right)
- rough depth (metres)
- timestamp

**Recall** is used on find/where-is. Looking around **fills** memory without announcing every insert.

---

## 6. Detection stack (on-device)

```
Camera
  ├─ Ultralytics YOLOView (primary live boxes)
  ├─ ML Kit Object Detection + Image Labeling (name enrichment)
  └─ optional custom TFLite / MiDaS depth (assets/models/)
        → WalkingPipeline
        → GuideAlertEngine (priority + cooldown)
        → VoiceAnnouncementQueue (TTS)
        → MemoryTracker.observeDetections (silent)
```

- **Rust native engine is OFF** for this MVP (`EngineConfig.ENABLE_RUST_NATIVE_ENGINE = false`).
- Gemini is **not** used for continuous walking frames.

---

## 7. Optional cloud pieces

| Feature | Needs | If missing |
|---------|-------|------------|
| Open chat / hard Q&A | `GEMINI_API_KEY` and/or Render `API_BASE_URL` | Core vision + find + call still work |
| Outdoor “navigate to …” | `GEOAPIFY_API_KEY` | Local find / look ahead still work |
| Phone OTP / cloud profiles | Not in this MVP | Local prefs only |

---

## 8. Quick test checklist

1. **1 tap** → say “look ahead” → hear nearby object names within ~10 s in a furnished room.  
2. Double tap home → say “find chair” → last-seen line (if logged) → live find.  
3. Say “call …” / “emergency” with airplane mode → still dials.  
4. Say a joke / translation with internet → companion/Gemini answer.  
5. Live screen: double tap returns home; TTS is not killed by a background mic loop.

---

## 9. What this build is *not*

- Not a full indoor map / SLAM.  
- Not “identify everything.”  
- Not continuous cloud vision.  
- Not TalkBack-perfect gesture UX yet.

**Product promise for this version:** voice-first indoor companion that names nearby objects when confident, remembers last-seen for find, and keeps call/emergency reliable offline.
}