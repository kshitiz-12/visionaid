import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../walking/data/box_size_depth_provider.dart';
import '../../domain/services/object_detector_service.dart';
import 'custom_yolo_catalog.dart';
import 'scene_vocab.dart';

/// Maps Ultralytics YOLO boxes onto VisionAid's walking detections.
///
/// Official COCO models miss wall / stairs / ladder. Custom TFLite classes
/// fill those; large unlabeled path blobs still invent wall/obstacle shapes.
class YoloMapper {
  YoloMapper._();

  static List<RawDetection> toRaw(
    List<YOLOResult> results, {
    double minConfidence = 0.16,
  }) {
    final out = <RawDetection>[];
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      if (r.confidence < minConfidence) {
        continue;
      }
      final n = r.normalizedBox;
      final left = n.left.clamp(0.0, 1.0);
      final top = n.top.clamp(0.0, 1.0);
      final right = n.right.clamp(0.0, 1.0);
      final bottom = n.bottom.clamp(0.0, 1.0);
      if (right <= left || bottom <= top) {
        continue;
      }
      final w = right - left;
      final h = bottom - top;
      final area = (w * h).clamp(0.0, 1.0);
      if (area < 0.004) {
        continue;
      }
      var named = _resolveName(r);
      if (named.isEmpty) {
        named = _barrierName(left: left, right: right, area: area);
      }
      if (named.isEmpty) {
        named = _shapeName(w: w, h: h);
      }
      if (named.isEmpty) {
        continue;
      }
      final metres = BoxSizeDepthProvider.metresFromBox(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );
      out.add(
        RawDetection(
          label: named,
          confidence: r.confidence.clamp(0.0, 1.0),
          distance: area,
          boxWidth: w,
          boxHeight: h,
          boxLeft: left,
          boxTop: top,
          frameWidth: 1,
          frameHeight: 1,
          trackingId: null,
          timestamp: DateTime.now(),
          distanceMeters: metres,
        ),
      );
    }
    return out;
  }

  static String _resolveName(YOLOResult r) {
    var named = SceneVocab.normalize(r.className);
    if (named.isNotEmpty) {
      return named;
    }
    // Only map indices when fine-tuned weights are loaded — COCO indices
    // collide with custom class order (0 = person vs stairs).
    if (CustomYoloCatalog.modelBundled == true) {
      final fromIndex = CustomYoloCatalog.nameOf(r.classIndex);
      if (fromIndex != null) {
        return SceneVocab.normalize(fromIndex);
      }
    }
    return '';
  }

  /// Image-label hazards (stairs/wall/ladder) without boxes → corridor boxes.
  static List<RawDetection> hazardBoxesFromLabels(List<RawDetection> labels) {
    final out = <RawDetection>[];
    final seen = <String>{};
    for (final l in labels) {
      final name = SceneVocab.normalize(l.label);
      if (!CustomYoloCatalog.isHazard(name) || !seen.add(name)) {
        continue;
      }
      final top = name == 'stairs' ||
              name == 'ladder' ||
              name == 'pothole' ||
              name == 'open_drain' ||
              name == 'curb'
          ? 0.42
          : 0.18;
      final bottom = 0.95;
      const left = 0.32;
      const right = 0.68;
      final w = right - left;
      final h = bottom - top;
      final metres = name == 'stairs' ||
              name == 'ladder' ||
              name == 'pothole' ||
              name == 'open_drain'
          ? 1.0
          : 1.3;
      out.add(
        RawDetection(
          label: name,
          confidence: l.confidence.clamp(0.45, 1.0),
          distance: (w * h).clamp(0.2, 1.0),
          boxWidth: w,
          boxHeight: h,
          boxLeft: left,
          boxTop: top,
          frameWidth: 1,
          frameHeight: 1,
          timestamp: DateTime.now(),
          distanceMeters: metres,
        ),
      );
    }
    return out;
  }

  static String _barrierName({
    required double left,
    required double right,
    required double area,
  }) {
    final cx = (left + right) / 2;
    final inPath = cx > 0.28 && cx < 0.72;
    if (!inPath) {
      return '';
    }
    if (area >= 0.48) {
      return 'wall';
    }
    if (area >= 0.22) {
      return 'obstacle';
    }
    return '';
  }

  static String _shapeName({required double w, required double h}) {
    if (h >= 0.55) {
      return 'tall thing';
    }
    if (w >= 0.45) {
      return 'wide thing';
    }
    if (h <= 0.18) {
      return 'low thing';
    }
    return 'nearby thing';
  }
}
