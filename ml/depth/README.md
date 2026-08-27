# Monocular depth (Phase 3)

Walking uses **box-size depth** by default. Drop MiDaS TFLite to fuse relative
depth with that prior.

## Enable MiDaS

```bash
python ml/depth/fetch_midas.py
# → flutter/assets/models/midas_small.tflite (~63 MB)
flutter build apk --release
```

Source: [MiDaS v2.1 `model_opt.tflite`](https://github.com/isl-org/MiDaS/releases/tag/v2_1)

## Behaviour

- Input 256×256 RGB → relative inverse-depth map
- Per-box mean fused with box-size metres (not a laser tape)
- If the asset is missing, app still runs (`activeSource: box-size`)

## Paper honesty

Report **relative + calibrated approximate metres**, not absolute metric depth
without camera intrinsics calibration.
