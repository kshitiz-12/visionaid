# On-device models

## Bundled now

- `efficientdet_lite0.tflite` — ML Kit fallback (COCO-style everyday objects).
- `visionaid_custom.names` — class list for the fine-tuned detector (order is fixed).
- `visionaid_custom.tflite` — optional custom detector (drop-in).
- `midas_small.tflite` — optional MiDaS depth (drop-in; see `ml/depth/README.md`).

Live walking uses Ultralytics **YOLO** (`yolo26s` by default). If you drop a trained
`visionaid_custom.tflite` into this folder and rebuild the APK, the app loads it
automatically (see `CustomYoloCatalog` / `YoloObjectDetector.resolveModelPath()`).

## Custom YOLO (hazards + INR + med packs)

Official COCO YOLO does **not** see stairs, walls, open drains, or rupee notes.
Fine-tune your own detector so walking stays on-device and Gemini is only for hard
questions (OCR, cooked food, complex judgment).

### Classes (order must not change)

See `visionaid_custom.names` and `ml/custom_yolo/data.example.yaml`.

1. Hazards: stairs, ladder, pothole, open_drain, curb, wet_floor_sign, wall, door  
2. Notes: inr_10 … inr_500  
3. Med packs: blister_pack, syrup_bottle, dropper_bottle, ointment_tube  

### Train + export (Colab)

```bash
# On Colab / GPU machine
pip install ultralytics
# Point data.yaml at your labeled images (copy from data.example.yaml)
python ml/custom_yolo/train_export_colab.py --data /path/to/data.yaml --model yolo26n.pt
```

Copy the printed file to:

```text
flutter/assets/models/visionaid_custom.tflite
```

Then rebuild the APK. Without that file, the app keeps using official `yolo26s`.

### Gemini still owns

Fine print / OCR, cooked food recognition, and open-ended “what should I do” questions.
