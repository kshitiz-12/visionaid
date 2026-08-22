import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../domain/services/object_detector_service.dart';

/// Names what is in a frame. Default object detection often returns unlabeled
/// "object" boxes; image labeling provides real category names.
class SceneLabeler {
  SceneLabeler()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.5),
        );

  final ImageLabeler _labeler;

  Future<List<RawDetection>> label(InputImage image) async {
    final labels = await _labeler.processImage(image);
    final named = labels
        .where((l) => l.confidence >= 0.5)
        .map((l) => RawDetection(
              label: _friendly(l.label),
              confidence: l.confidence,
              distance: 0.55,
            ))
        .where((d) => d.label.isNotEmpty && d.label != 'object')
        .toList();
    named.sort((a, b) => b.confidence.compareTo(a.confidence));
    return named.take(4).toList();
  }

  static List<RawDetection> preferNamed(
    List<RawDetection> objects,
    List<RawDetection> labels,
  ) {
    final fromBoxes = objects
        .where((o) {
          final l = o.label.trim().toLowerCase();
          return l.isNotEmpty && l != 'object' && l != 'unknown';
        })
        .toList();
    if (fromBoxes.isNotEmpty) {
      return fromBoxes;
    }
    return labels;
  }

  String _friendly(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty || t == 'object' || t == 'unknown') {
      return '';
    }
    return t;
  }

  Future<void> dispose() => _labeler.close();
}
