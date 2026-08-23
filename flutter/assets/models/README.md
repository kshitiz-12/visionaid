# On-device models

Bundled: **EfficientDet Lite0 (COCO)** as `efficientdet_lite0.tflite`.

This uses the same 80 everyday classes as a typical **YOLOv8n** (person, chair, car, bottle, …). **Wall is not one of those classes.** A large unlabeled block in the walking path is spoken as wall or obstacle.

Swapping to YOLO would mainly change speed and how many of those 80 classes get boxes. It would not magically see blank walls. Depth / ARCore or a custom wall model would.

Headphones come from image labeling, not COCO.
