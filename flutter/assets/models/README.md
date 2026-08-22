# On-device models

VisionAid ships with **ML Kit Object Detection** as the default on-device detector
(privacy-first, no cloud upload of frames).

To swap in **YOLOv8 Nano TFLite**:

1. Export `yolov8n.tflite` (Ultralytics).
2. Place it here as `yolov8n.tflite`.
3. Implement `YoloTfliteDetector` against `ObjectDetectorService`.
4. Point `objectDetectorProvider` at the YOLO implementation.

Until then, the production path is ML Kit → Context Engine → TTS.
