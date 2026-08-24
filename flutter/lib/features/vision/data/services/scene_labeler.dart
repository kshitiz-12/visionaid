import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../domain/services/object_detector_service.dart';
import 'scene_vocab.dart';

/// Names what is in a frame. Default object detection often returns unlabeled
/// "object" boxes; image labeling provides real category names.
class SceneLabeler {
  SceneLabeler()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.22),
        );

  final ImageLabeler _labeler;

  Future<List<RawDetection>> label(InputImage image) async {
    final labels = await _labeler.processImage(image);
    final named = <RawDetection>[];
    for (final item in labels) {
      if (item.confidence < 0.22) {
        continue;
      }
      final friendly = SceneVocab.normalize(item.label);
      if (friendly.isEmpty) {
        continue;
      }
      named.add(
        RawDetection(
          label: friendly,
          confidence: item.confidence,
          distance: 0.5,
        ),
      );
    }
    named.sort((a, b) => b.confidence.compareTo(a.confidence));
    return named.take(6).toList();
  }

  /// Boxes give distance; labels give names. Keep both, drop junk "object".
  static List<RawDetection> merge(
    List<RawDetection> objects,
    List<RawDetection> labels,
  ) {
    final proximity = objects.isEmpty
        ? 0.45
        : objects.map((o) => o.distance).reduce((a, b) => a > b ? a : b);

    final merged = <RawDetection>[];
    final seen = <String>{};

    void add(RawDetection d) {
      final name = SceneVocab.normalize(d.label);
      if (name.isEmpty || !seen.add(name)) {
        return;
      }
      merged.add(
        RawDetection(
          label: name,
          confidence: d.confidence,
          distance: d.distance > 0.05 ? d.distance : proximity,
          isMoving: d.isMoving,
          boxWidth: d.boxWidth,
          boxHeight: d.boxHeight,
          boxLeft: d.boxLeft,
          boxTop: d.boxTop,
          frameWidth: d.frameWidth,
          frameHeight: d.frameHeight,
          trackingId: d.trackingId,
          timestamp: d.timestamp,
        ),
      );
    }

    for (final o in objects) {
      add(_namedBox(o, labels));
    }
    for (final l in labels) {
      add(
        RawDetection(
          label: l.label,
          confidence: l.confidence,
          distance: proximity,
        ),
      );
    }

    merged.sort((a, b) {
      final byConf = b.confidence.compareTo(a.confidence);
      if (byConf != 0) {
        return byConf;
      }
      return b.distance.compareTo(a.distance);
    });
    return merged.take(8).toList();
  }

  static RawDetection _namedBox(RawDetection box, List<RawDetection> labels) {
    final current = SceneVocab.normalize(box.label);
    if (current.isNotEmpty && current != 'obstacle' && current != 'wall') {
      return box.copyWith(label: current);
    }
    for (final label in labels) {
      final name = SceneVocab.normalize(label.label);
      if (name.isEmpty || name == 'obstacle' || name == 'wall') {
        continue;
      }
      return box.copyWith(
        label: name,
        confidence: label.confidence > box.confidence ? label.confidence : box.confidence,
      );
    }
    return box;
  }

  static List<RawDetection> preferNamed(
    List<RawDetection> objects,
    List<RawDetection> labels,
  ) =>
      merge(objects, labels);

  Future<void> dispose() => _labeler.close();
}
