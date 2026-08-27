# VisionAid — what it does and how to test it

No login. English or Hindi. Name and emergency contact stay on the phone.

## Home (big mic)

Stay on this screen for talk, call, and questions. **Do not open Look ahead** unless you want walking.

Tap **anywhere** on the home screen (you do not need to hit the mic). Wait about half a second after the last tap so it can count:

| Taps | Action |
|------|--------|
| 1 | Speak (same as the mic) |
| 2 | Look ahead |
| 3 | Emergency call |
| Two fingers down at once | Close the app |

TalkBack’s double-tap-to-activate can fight this. Turn TalkBack off while testing these gestures, or use the labelled buttons.

| You say / tap | What should happen |
|---------------|-------------------|
| Tap **once** anywhere, then ask anything (“What is potato in English?”, “aaloo ko English mein kya kehte hain”, plans, jokes) | Waits for Gemini, then **speaks the full answer**. Working… then the mic comes back. Needs internet + Render. |
| “What is in front of me?” / “ye kya hai?” | Takes **one photo** and describes it (left / right / ahead). Not the live walking loop. |
| “Call Harry” | Dials that contact. Not AI. |
| “Call me” / “Emergency” / tap **Emergency** | Dials the **saved emergency number**. If the call fails, opens SMS with location. |
| “Guide me” or tap **Look ahead** | Live camera walking. **No continuous Gemini.** |
| “Find my purse” / “Where is the chair” | Opens **live find mode** (`/live?target=…`). Beeps speed up as you center on it. |
| “Navigate to the park” / “Take me to …” | Outdoor walking directions (needs `GEOAPIFY_API_KEY`). |
| “Text Mom …” / “WhatsApp Harry saying …” | On-phone messaging. |
| “Read this” | Photo + OCR, then spoken. |
| “Quit” / “quiet” / two fingers down | Closes the app. Back button does not. |

## Look ahead (walking)

Hold the phone **chest-high, camera forward**, walk slowly.

You should hear a **short** line like “Chair, ahead, one metre.” Quiet unless something is in your path. **Path clear** when the way opens. **Beep + vibration** inside about 1 metre.

- Named when it can: chair, bottle, person, table…
- If it cannot name it: **tall / wide / low / nearby thing** — never a potato from this screen.

Say **stop looking**, tap Stop looking, or **tap twice** anywhere to go home. **Three taps** starts emergency. **Two fingers down** closes the app.

**Wrong test:** asking “what is aalu” while Look ahead is open. That screen only listens for stop. Ask on the **home mic**.

## Settings

Language, your name, emergency name/number, voice speed. No research overlay.

## Honest limits

Distances are approximate. Walking cannot name food. First chat after Render sleeps can be slow. Rebuild the APK after UI/code changes.

Optional: drop a trained `visionaid_custom.tflite` into `flutter/assets/models/` (stairs, drains, INR notes, med packs) so walking names those on-device. Until then, official YOLO + Image Labeler fill what they can. See `flutter/assets/models/README.md`.

Optional depth: `python ml/depth/fetch_midas.py` adds MiDaS fusion. Outdoor routes need `GEOAPIFY_API_KEY`. Study protocol: `docs/user-study-protocol.md`.
