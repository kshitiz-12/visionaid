import '../../../../services/memory_tracker.dart';
import '../../domain/services/object_detector_service.dart';
import 'scene_vocab.dart';

/// Filters detections before walking / speech — trust over chatter.
class SceneSpeechFilter {
  SceneSpeechFilter._();

  static bool hasRealBox(RawDetection d) =>
      d.boxWidth > 0.01 && d.boxHeight > 0.01;

  static List<RawDetection> forPipeline(
    List<RawDetection> raw, {
    required bool targetSearch,
  }) {
    return [
      for (final d in raw)
        if (keep(d, targetSearch: targetSearch)) d,
    ];
  }

  static bool keep(RawDetection d, {required bool targetSearch}) {
    final label = SceneVocab.normalize(d.label);
    if (label.isEmpty) {
      return false;
    }
    if (MemoryTracker.isAmbientNoise(label) || SceneVocab.isVisionNoise(label)) {
      return false;
    }
    final realBox = hasRealBox(d);
    if (SceneVocab.isOutdoorVehicle(label) && d.confidence < 0.82) {
      return false;
    }
    if (!realBox && !targetSearch) {
      return false;
    }
    if (!targetSearch && d.confidence < 0.45) {
      return false;
    }
    return true;
  }
}
