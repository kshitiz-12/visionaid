import 'dart:io';

import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../domain/services/object_detector_service.dart';
import 'mlkit_object_detector.dart';
import 'yolo_mapper.dart';

/// Still-image YOLO (home photo). Live walking uses [YOLOView] instead.
class YoloObjectDetector implements ObjectDetectorService {
  YoloObjectDetector({MlKitObjectDetector? fallback})
      : _fallback = fallback ?? MlKitObjectDetector(stream: false);

  final MlKitObjectDetector _fallback;
  YOLO? _yolo;
  bool _yoloFailed = false;

  static String modelId() {
    return YOLO.defaultOfficialModel(task: YOLOTask.detect) ?? 'yolo26n';
  }

  Future<bool> _ensureYolo() async {
    if (_yoloFailed) {
      return false;
    }
    if (_yolo?.isInitialized == true) {
      return true;
    }
    try {
      _yolo = YOLO(
        modelPath: modelId(),
        task: YOLOTask.detect,
        useGpu: true,
        useMultiInstance: true,
      );
      final ok = await _yolo!.loadModel();
      if (!ok) {
        _yoloFailed = true;
        return false;
      }
      return true;
    } catch (_) {
      _yoloFailed = true;
      return false;
    }
  }

  @override
  Future<List<RawDetection>> detect(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw StateError('Captured image not found.');
    }
    if (await _ensureYolo()) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        final raw = await _yolo!.predict(bytes, confidenceThreshold: 0.25);
        final list = raw['detections'];
        if (list is List) {
          final results = <YOLOResult>[];
          for (final item in list) {
            if (item is Map) {
              results.add(YOLOResult.fromMap(item));
            }
          }
          return YoloMapper.toRaw(results);
        }
      } catch (_) {
        _yoloFailed = true;
      }
    }
    return _fallback.detect(imagePath);
  }

  @override
  Future<List<RawDetection>> detectInput(InputImage image) {
    return _fallback.detectInput(image);
  }

  @override
  Future<void> dispose() async {
    await _yolo?.dispose();
    await _fallback.dispose();
  }
}
