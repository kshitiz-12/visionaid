import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../domain/services/object_detector_service.dart';
import 'scene_vocab.dart';

/// Names what is in a frame. Default object detection often returns unlabeled
/// "object" boxes; image labeling provides real category names.
class SceneLabeler {
  SceneLabeler()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.32),
        );

  final ImageLabeler _labeler;

  Future<List<RawDetection>> label(InputImage image) async {
    final labels = await _labeler.processImage(image);
    final named = <RawDetection>[];
    for (final item in labels) {
      if (item.confidence < 0.32) {
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
    // Prefer concrete objects over weak animal false-positives in labels.
    return named.where((d) {
      if ((d.label == 'dog' || d.label == 'cat') && d.confidence < 0.55) {
        return false;
      }
      return true;
    }).take(6).toList();
  }

  Future<List<RawDetection>> labelFile(String path) {
    return label(InputImage.fromFilePath(path));
  }

  /// Boxes give distance; labels give names. Keep both, drop junk "object".
  ///
  /// Label-only hits (no box) get a synthetic lower-center box so find-mode
  /// can still speak direction and drive haptic geiger (e.g. shoes on floor).
  static List<RawDetection> merge(
    List<RawDetection> objects,
    List<RawDetection> labels, {
    bool includeLabelOnly = false,
  }) {
    final proximity = objects.isEmpty
        ? 0.45
        : objects.map((o) => o.distance).reduce((a, b) => a > b ? a : b);

    final merged = <RawDetection>[];
    final seen = <String>{};

    void add(RawDetection d, {required bool fromLabelOnly}) {
      final name = SceneVocab.normalize(d.label);
      if (name.isEmpty || !seen.add(name)) {
        return;
      }
      if (fromLabelOnly && !includeLabelOnly) {
        return;
      }
      var out = RawDetection(
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
        distanceMeters: d.distanceMeters,
      );
      if (out.boxWidth <= 0 || out.boxHeight <= 0) {
        if (fromLabelOnly) {
          if (!includeLabelOnly) {
            return;
          }
          // Find-mode only: synthetic lower-center box for floor objects.
          out = out.copyWith(
            boxLeft: 0.28,
            boxTop: 0.55,
            boxWidth: 0.44,
            boxHeight: 0.40,
            frameWidth: 1,
            frameHeight: 1,
            distance: proximity.clamp(0.25, 0.65),
            distanceMeters: out.distanceMeters ?? 1.0,
          );
        }
      }
      merged.add(out);
    }

    for (final o in objects) {
      add(_namedBox(o, labels), fromLabelOnly: false);
    }
    for (final l in labels) {
      add(
        RawDetection(
          label: l.label,
          confidence: l.confidence,
          distance: proximity,
        ),
        fromLabelOnly: true,
      );
    }

    merged.sort((a, b) {
      final byConf = b.confidence.compareTo(a.confidence);
      if (byConf != 0) {
        return byConf;
      }
      return b.distance.compareTo(a.distance);
    });
    return merged.take(12).toList();
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
