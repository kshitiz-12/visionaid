#!/usr/bin/env python3
"""Train + export VisionAid custom YOLO for Flutter (Android TFLite).

Run on Google Colab (GPU) or a local machine with ultralytics installed:

  pip install ultralytics
  python train_export_colab.py --data /path/to/data.yaml

Then copy the printed .tflite into:
  flutter/assets/models/visionaid_custom.tflite

Class order must match flutter/assets/models/visionaid_custom.names
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="VisionAid custom YOLO train/export")
    parser.add_argument(
        "--data",
        required=True,
        help="Path to data.yaml (see data.example.yaml)",
    )
    parser.add_argument(
        "--model",
        default="yolo26n.pt",
        help="Base checkpoint (yolo26n.pt or yolo26s.pt)",
    )
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument(
        "--out",
        default="visionaid_custom.tflite",
        help="Output TFLite filename",
    )
    args = parser.parse_args()

    from ultralytics import YOLO

    data = Path(args.data).resolve()
    if not data.is_file():
        raise SystemExit(f"data.yaml not found: {data}")

    print("Training…")
    model = YOLO(args.model)
    model.train(
        data=str(data),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        project="visionaid_runs",
        name="custom_detect",
        exist_ok=True,
    )

    best = Path("visionaid_runs/custom_detect/weights/best.pt")
    if not best.is_file():
        # Ultralytics may nest runs; fall back to trainer's best
        best = Path(model.trainer.best) if getattr(model, "trainer", None) else best
    print(f"Best weights: {best}")

    finetuned = YOLO(str(best))
    # Android / ultralytics_yolo expects detect TFLite without end2end NMS graph.
    print("Exporting TFLite (w8a32-style int8 weights)…")
    exported = finetuned.export(
        format="tflite",
        imgsz=args.imgsz,
        int8=True,
        nms=False,
    )
    src = Path(exported)
    dest = Path(args.out).resolve()
    dest.write_bytes(src.read_bytes())
    print(f"Wrote {dest}")
    print("Next: copy into flutter/assets/models/visionaid_custom.tflite and rebuild the APK.")


if __name__ == "__main__":
    main()
