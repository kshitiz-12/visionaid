import '../../domain/entities/detected_object.dart';
import '../../domain/repositories/vision_repository.dart';

class VisionRepositoryImpl implements VisionRepository {
  @override
  Future<List<DetectedObject>> analyzeFrame({
    required List<Map<String, dynamic>> detections,
  }) async {
    if (detections.isEmpty) {
      return const [];
    }

    final objects = detections.map((detection) {
      final label = (detection['label'] as String? ?? 'unknown').toLowerCase();
      final confidence = (detection['confidence'] as num? ?? 0.0).toDouble();
      final distance = (detection['distance'] as num? ?? 0.0).toDouble();
      final isMoving = detection['isMoving'] as bool? ?? false;
      final importance = (detection['importance'] as num? ?? 0.3).toDouble();
      final navigationRisk = (detection['navigationRisk'] as num? ?? 0.1).toDouble();

      return DetectedObject(
        label: label,
        confidence: confidence.clamp(0.0, 1.0),
        distance: distance.clamp(0.0, 1.0),
        isMoving: isMoving,
        importance: importance.clamp(0.0, 1.0),
        navigationRisk: navigationRisk.clamp(0.0, 1.0),
      );
    }).toList();

    objects.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return objects;
  }
}
