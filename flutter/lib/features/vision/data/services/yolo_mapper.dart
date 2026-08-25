import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../walking/data/box_size_depth_provider.dart';
import '../../domain/services/object_detector_service.dart';
import 'scene_vocab.dart';

/// Maps Ultralytics YOLO boxes onto VisionAid's walking detections.
class YoloMapper {
  YoloMapper._();

  static List<RawDetection> toRaw(
    List<YOLOResult> results, {
    double minConfidence = 0.18,
  }) {
    final out = <RawDetection>[];
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      if (r.confidence < minConfidence) {
        continue;
      }
      final named = SceneVocab.normalize(r.className);
      if (named.isEmpty) {
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
}
