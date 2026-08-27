#!/usr/bin/env python3
"""Download MiDaS v2.1 small TFLite for VisionAid walking depth.

Usage:
  python ml/depth/fetch_midas.py

Writes:
  flutter/assets/models/midas_small.tflite

Then rebuild the APK. Without this file, walking keeps box-size depth.
"""

from __future__ import annotations

import urllib.request
from pathlib import Path

URL = "https://github.com/isl-org/MiDaS/releases/download/v2_1/model_opt.tflite"
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "flutter" / "assets" / "models" / "midas_small.tflite"


def main() -> None:
    DEST.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {URL}")
    urllib.request.urlretrieve(URL, DEST)
    size_mb = DEST.stat().st_size / (1024 * 1024)
    print(f"Wrote {DEST} ({size_mb:.1f} MB)")
    print("Rebuild the APK to enable midas+box-size fusion.")


if __name__ == "__main__":
    main()
