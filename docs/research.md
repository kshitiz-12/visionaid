# VisionAid++ Research Notes

## Research contribution

**Adaptive Context-Aware Decision Engine**

VisionAid++ does not announce every object detected by YOLO. Instead, a dedicated Context Engine module scores each detection and speaks only when the priority exceeds a threshold.

## Problem statement

Continuous object announcements create cognitive overload for visually impaired users. Existing vision apps often read everything the model detects, which is noisy and unusable in real environments.

## Proposed pipeline

```
Camera
  ↓
YOLOv8 Nano (on-device, TFLite)
  ↓
Object Detection results
  ↓
Context Engine (testable module)
  ↓
Risk Calculation
  ↓
Priority Ranking
  ↓
Voice Response (TTS)
```

## Priority score factors (planned)

| Factor | Description |
|--------|-------------|
| confidence | Model detection confidence |
| distance | Estimated distance (ARCore depth) |
| motion | Approaching vs static object |
| user intent | Active voice command context |
| object importance | User favorites, learned preferences |
| navigation risk | Obstacles in travel path |
| environment | Indoor vs outdoor mode |
| historical context | Recent detections, location memory |

## Foundation status

The foundation includes a stub priority scoring utility at `flutter/lib/core/utils/context_priority_score.dart` with unit tests. Full Context Engine implementation is a **future phase**.

## Privacy constraints

Research data collection must respect user privacy:

- Camera frames remain on device by default
- Detection history stores metadata only (object name, confidence, distance, risk score)
- Cloud processing (Gemini) is optional and clearly disclosed
- No sensitive images in logs or research exports without explicit consent

## Evaluation metrics (planned)

- Reduction in spoken announcements vs naive baseline
- Task completion time in navigation scenarios
- User-reported cognitive load (subjective scale)
- False negative rate for high-risk obstacles

## Related work areas

- Accessible mobile navigation for blind users
- On-device object detection with YOLO
- Attention-based alert prioritization
- Multimodal context fusion (vision + voice + location)

## Next research steps

1. Implement full Context Engine module with configurable weights
2. Collect labeled scenarios for priority calibration
3. Integrate ARCore distance into risk scoring
4. Compare naive vs context-aware announcement rates in user studies
