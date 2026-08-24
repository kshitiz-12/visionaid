import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../../domain/services/object_detector_service.dart';
import 'scene_vocab.dart';

/// On-device detection: COCO EfficientDet (person, laptop, …) with ML Kit fallback.
class MlKitObjectDetector implements ObjectDetectorService {
  MlKitObjectDetector({bool stream = true})
      : _stream = stream,
        _detector = _create(stream: stream, custom: true);

  static const modelAsset = 'assets/models/efficientdet_lite0.tflite';

  final bool _stream;
  ObjectDetector _detector;
  ObjectDetector? _still;
  bool _custom = true;
  bool _stillCustom = true;

  static ObjectDetector _create({required bool stream, required bool custom}) {
    final mode = stream ? DetectionMode.stream : DetectionMode.single;
    if (custom) {
      return ObjectDetector(
        options: LocalObjectDetectorOptions(
          mode: mode,
          modelPath: modelAsset,
          classifyObjects: true,
          multipleObjects: true,
          confidenceThreshold: 0.18,
          maximumLabelsPerObject: 2,
        ),
      );
    }
    return ObjectDetector(
      options: ObjectDetectorOptions(
        mode: mode,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
  }

  @override
  Future<List<RawDetection>> detect(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw StateError('Captured image not found.');
    }
    final image = InputImage.fromFilePath(imagePath);
    _still ??= _create(stream: false, custom: true);
    try {
      return _mapObjects(await _still!.processImage(image), image);
    } catch (_) {
      if (_stillCustom) {
        _stillCustom = false;
        await _still?.close();
        _still = _create(stream: false, custom: false);
        return _mapObjects(await _still!.processImage(image), image);
      }
      rethrow;
    }
  }

  @override
  Future<List<RawDetection>> detectInput(InputImage image) async {
    try {
      return _mapObjects(await _detector.processImage(image), image);
    } catch (_) {
      if (!_custom) {
        rethrow;
      }
      _custom = false;
      await _detector.close();
      _detector = _create(stream: _stream, custom: false);
      return _mapObjects(await _detector.processImage(image), image);
    }
  }

  List<RawDetection> _mapObjects(List<DetectedObject> objects, InputImage image) {
    final size = image.metadata?.size;
    final area = size == null
        ? _fallbackArea(objects)
        : (size.width * size.height).clamp(1.0, double.infinity);

    final detections = <RawDetection>[];
    for (final obj in objects) {
      final labels = obj.labels;
      final best = labels.isEmpty
          ? null
          : labels.reduce((a, b) => a.confidence >= b.confidence ? a : b);
      final rawLabel = (best?.text ?? '').toLowerCase();
      var named = SceneVocab.normalize(rawLabel);
      final confidence = (best?.confidence ?? 0.45).toDouble();
      if (best != null && best.confidence < 0.16 && named.isNotEmpty) {
        continue;
      }
      final box = obj.boundingBox;
      final boxArea = (box.width * box.height).clamp(0.0, area);
      final distance = (boxArea / area).clamp(0.0, 1.0);
      if (distance < 0.006) {
        continue;
      }

      // COCO/YOLO do not have "wall". A big unlabeled block in view is treated
      // as something you can walk into.
      if (named.isEmpty || named == 'object') {
        named = _barrierName(box: box, area: area, size: size);
      }
      if (named.isEmpty) {
        continue;
      }

      detections.add(
        RawDetection(
          label: named,
          confidence: confidence.clamp(0.0, 1.0),
          distance: distance < 0.05 ? 0.08 : distance,
          boxWidth: box.width,
          boxHeight: box.height,
          boxLeft: box.left,
          boxTop: box.top,
          frameWidth: size?.width ?? 0,
          frameHeight: size?.height ?? 0,
          trackingId: obj.trackingId,
          timestamp: DateTime.now(),
        ),
      );
    }
    return detections;
  }

  String _barrierName({
    required Rect box,
    required double area,
    required Size? size,
  }) {
    final frac = ((box.width * box.height) / area).clamp(0.0, 1.0);
    final cx = size == null || size.width <= 0
        ? 0.5
        : (box.left + box.width / 2) / size.width;
    final inPath = cx > 0.28 && cx < 0.72;
    if (frac >= 0.48 && inPath) {
      return 'wall';
    }
    if (frac >= 0.22 && inPath) {
      return 'obstacle';
    }
    return '';
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
  Future<void> dispose() async {
    await _detector.close();
    await _still?.close();
  }
}
