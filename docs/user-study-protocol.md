# VisionAid++ user study protocol (Phase 5)

Target venues: IEEE TACCESS / ACM ASSETS style evaluation.

## Participants

- **N ≥ 20** (blind / low-vision preferred; sighted-blindfolded OK for pilot)
- Ages 18+, informed consent, ethics board if affiliated

## Tasks (within-subjects, counterbalanced)

| Task | Description | Success |
|------|-------------|---------|
| T1 Corridor walk | 15 m hallway with chair + bag obstacles | Reach end without collision |
| T2 Stairs / curb | Approach marked stairs or curb | Stop before hazard, verbal alert |
| T3 Find object | “Find my purse/chair” live search | Reach object ≤ 3 min |
| T4 Outdoor route | “Navigate to [landmark]” (if API key set) | Complete 2 turns correctly |
| T5 Call contact | “Call mummy” with emoji contact name | Correct dial |

Arms (optional A/B):

1. **VisionAid++** (YOLO + fused depth + cooldowns)
2. **Baseline** (announce every detection, no cooldown) — toggle via research build if needed
3. **Commercial** (Lookout / Seeing AI) — same course, separate sessions

## Metrics

| Metric | Target | How collected |
|--------|--------|---------------|
| Collision rate | Lower is better | Observer count / course |
| Task completion time | Minutes | Stopwatch + app `ResearchMetrics` |
| Mean end-to-end latency | **&lt; 150 ms** ideal | `cam→tts` in study JSON |
| Announcement count | Lower without missing hazards | `announce` events |
| SUS | **&gt; 85** | Questionnaire after session |
| Preference | Rank arms | Interview |

## App logging

On Look ahead / outdoor route exit, JSON is written under app documents:

`visionaid_study_<sessionId>.json`

Pull with:

```bash
adb shell run-as com.example.visionaid ls app_flutter/
# or use Device File Explorer
```

Fields: `latency`, `announce`, `detect`, `route_ready`, `arrived`.

## Confusion matrix (offline labeling)

Film courses; label frames for hazards. Fill:

`docs/templates/confusion-matrix.csv`

Conditions: Day / Night / Motion blur. Report mAP@50, FNR, inference ms.

## SUS (10 items, 1–5)

Use standard System Usability Scale; score = `((sum odd) - 5) + (25 - sum even)) * 2.5`.

Template answers sheet: `docs/templates/sus-scoresheet.md`

## Reporting checklist

- [ ] Demographics table  
- [ ] Per-task TCT + collisions  
- [ ] Latency mean / p95  
- [ ] SUS mean ± SD  
- [ ] Confusion matrices by lighting  
- [ ] Limitations (box-size vs MiDaS, API key outdoor, sample size)
