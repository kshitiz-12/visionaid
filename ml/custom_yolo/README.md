# VisionAid custom YOLO

Fine-tune a small detector so walking can name hazards, INR notes, and medicine
pack shapes **on-device** (less Gemini).

## Files

| File | Role |
|------|------|
| `data.example.yaml` | Class names — copy and point `path` / `train` / `val` at your images |
| `train_export_colab.py` | Train + export TFLite for Android |
| `../flutter/assets/models/visionaid_custom.names` | Same class order as the app |

## Quick path (Colab)

1. Label images in YOLO format (one `.txt` per image, class ids 0–17).
2. Upload dataset; copy `data.example.yaml` → `data.yaml` and set paths.
3. Run:

```bash
!pip install ultralytics
!python train_export_colab.py --data data.yaml --model yolo26n.pt --epochs 50
```

4. Download `visionaid_custom.tflite` → `flutter/assets/models/`
5. Rebuild the APK. App auto-switches when the file is present.

Start with **hazards only** if you have limited labels; keep class ids stable
(do not reorder — leave unused classes empty in the dataset if needed).
