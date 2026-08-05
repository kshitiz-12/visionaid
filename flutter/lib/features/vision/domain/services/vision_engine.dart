import '../../data/repositories/vision_repository_impl.dart';
import '../entities/detected_object.dart';

class VisionEngine {
  VisionEngine({required this.repository});

  final VisionRepositoryImpl repository;

  Future<List<DetectedObject>> analyzeFrame({
    required List<Map<String, dynamic>> detections,
  }) async {
    return repository.analyzeFrame(detections: detections);
  }

  String summarizePriority(List<DetectedObject> objects) {
    if (objects.isEmpty) {
      return 'No objects detected in the current scene.';
    }

    final topObject = objects.first;
    if (topObject.isHazard) {
      return 'Hazard: ${topObject.label} detected ahead. Immediate caution recommended.';
    }

    return 'Relevant object: ${topObject.label}. Confidence ${topObject.confidence.toStringAsFixed(2)}.';
  }
}
