# VisionAid++ Research Notes

## Contribution

**Adaptive Context-Aware Decision Engine**

Do not announce every detector output. Score detections and speak only high-priority / hazard / intent-matched information, with announcement cooldown (`SpeakGate`).

## Implemented (not fabricated)

- Priority formula: `flutter/lib/core/utils/context_priority_score.dart` (unit tested)
- Ranking + spoken filtering: `flutter/lib/features/context_engine/`
- Duplicate suppression: `flutter/lib/core/utils/speak_gate.dart`
- Live camera + ML Kit labeling/detection (not YOLOv8 TFLite weights yet)
- Tests: intent, context, speak gate, voice repository

## Baseline vs VisionAid++ (experiment — not run)

| Arm | Behavior |
|-----|----------|
| Baseline | Speak all detections every frame |
| VisionAid++ | Context score + hazard first + cooldown |

**No user-study numbers exist in this repo.** Do not invent them.

## Planned measurements

Latency, announcement count, duplicates, risk recall, battery, task completion. Collect only with consent; store metadata not frames.

## Not in scope yet

Persistent spatial house map. YOLO Nano `.tflite` swap. ARCore meters. Gemini descriptions.
