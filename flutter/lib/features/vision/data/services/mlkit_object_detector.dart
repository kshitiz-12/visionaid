import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../../domain/services/object_detector_service.dart';

/// On-device object detection (ML Kit stream + still).
class MlKitObjectDetector implements ObjectDetectorService {
  MlKitObjectDetector({bool stream = true})
      : _detector = ObjectDetector(
          options: ObjectDetectorOptions(
            mode: stream ? DetectionMode.stream : DetectionMode.single,
            classifyObjects: true,
            multipleObjects: true,
          ),
        );

  final ObjectDetector _detector;

  @override
  Future<List<RawDetection>> detect(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw StateError('Captured image not found.');
    }
    return detectInput(InputImage.fromFilePath(imagePath));
  }

  @override
  Future<List<RawDetection>> detectInput(InputImage image) async {
    final objects = await _detector.processImage(image);
    final size = image.metadata?.size;
    final area = size == null
        ? _fallbackArea(objects)
        : (size.width * size.height).clamp(1.0, double.infinity);

    return objects.map((obj) {
      final labels = obj.labels;
      final best = labels.isEmpty
          ? null
          : labels.reduce((a, b) => a.confidence >= b.confidence ? a : b);
      final label = (best?.text ?? 'object').toLowerCase();
      final confidence = (best?.confidence ?? 0.55).toDouble();
      final box = obj.boundingBox;
      final boxArea = (box.width * box.height).clamp(0.0, area);
      final distance = (boxArea / area).clamp(0.05, 1.0);

      return RawDetection(
        label: label,
        confidence: confidence.clamp(0.0, 1.0),
        distance: distance,
        boxWidth: box.width,
        boxHeight: box.height,
      );
    }).toList();
  }

  double _fallbackArea(List<DetectedObject> objects) {
    double maxR = 1;
    double maxB = 1;
    for (final o in objects) {
      if (o.boundingBox.right > maxR) {
        maxR = o.boundingBox.right;
      }
      if (o.boundingBox.bottom > maxB) {
        maxB = o.boundingBox.bottom;
      }
    }
    return Size(maxR, maxB).width * Size(maxR, maxB).height;
  }

  @override
  Future<void> dispose() => _detector.close();
}
