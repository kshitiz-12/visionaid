# VisionAid++ — 10/10 roadmap status

## Complete (code)

| Phase | Milestone | Status |
|-------|-----------|--------|
| 1 | Find my X → live target + directional beeps | **Done** |
| 2 | IoU tracking + motion-adaptive FPS | **Done** |
| 3 | Monocular MiDaS fusion (optional TFLite) | **Done** (drop-in model) |
| 4 | Outdoor Geoapify walking turn-by-turn | **Done** (needs API key) |
| 5 | Study protocol + on-device metrics + templates | **Done** (run study offline) |

## You still configure

1. **MiDaS:** `python ml/depth/fetch_midas.py` → rebuild APK  
2. **Outdoor nav:** set `GEOAPIFY_API_KEY` in `flutter/.env` (Routing + Geocoding)  
3. **User study:** follow `docs/user-study-protocol.md` with N≥20

## Voice commands

| Say | Opens |
|-----|--------|
| Guide me / Look ahead | Live walking |
| Find my purse | Live find mode |
| Navigate to the park / Take me to … | Outdoor route |
| Call mummy | Contacts (fuzzy / Hindi / emoji) |
