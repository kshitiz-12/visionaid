import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../domain/services/object_detector_service.dart';
import 'custom_yolo_catalog.dart';
import 'mlkit_object_detector.dart';
import 'yolo_mapper.dart';

/// Still-image YOLO (home photo). Live walking uses [YOLOView] instead.
///
/// Prefers a fine-tuned `visionaid_custom.tflite` when bundled; otherwise
/// official `yolo26s` / `yolo26n`.
class YoloObjectDetector implements ObjectDetectorService {
  YoloObjectDetector({MlKitObjectDetector? fallback})
      : _fallback = fallback ?? MlKitObjectDetector(stream: false);

  final MlKitObjectDetector _fallback;
  YOLO? _yolo;
  bool _yoloFailed = false;
  static String? _cachedPath;
  static bool? _customPresent;

  /// Official Ultralytics detect model (fallback when no custom weights).
  static String officialModelId() {
    final ids = YOLO.officialModels(task: YOLOTask.detect);
    if (ids.contains('yolo26s')) {
      return 'yolo26s';
    }
    if (ids.contains('yolo26n')) {
      return 'yolo26n';
    }
    return YOLO.defaultOfficialModel(task: YOLOTask.detect) ?? 'yolo26s';
  }

  /// True when fine-tuned weights are in the APK.
  static Future<bool> hasCustomModel() async {
    if (_customPresent != null) {
      return _customPresent!;
    }
    try {
      await rootBundle.load(CustomYoloCatalog.assetModel);
      _customPresent = true;
    } catch (_) {
      _customPresent = false;
    }
    CustomYoloCatalog.modelBundled = _customPresent;
    return _customPresent!;
  }

  /// Asset path or official model id for [YOLO] / [YOLOView].
  static Future<String> resolveModelPath() async {
    if (_cachedPath != null) {
      return _cachedPath!;
    }
    if (await hasCustomModel()) {
      _cachedPath = CustomYoloCatalog.assetModel;
    } else {
      _cachedPath = officialModelId();
    }
    return _cachedPath!;
  }

  /// Sync helper for tests / after [resolveModelPath] has run.
  static String modelId() => _cachedPath ?? officialModelId();

  Future<bool> _ensureYolo() async {
    if (_yoloFailed) {
      return false;
    }
    if (_yolo?.isInitialized == true) {
      return true;
    }
    try {
      final path = await resolveModelPath();
      _yolo = YOLO(
        modelPath: path,
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
        final raw = await _yolo!.predict(bytes, confidenceThreshold: 0.22);
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
