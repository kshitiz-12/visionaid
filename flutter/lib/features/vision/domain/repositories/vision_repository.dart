import '../entities/detected_object.dart';

abstract class VisionRepository {
  Future<List<DetectedObject>> analyzeFrame({
    required List<Map<String, dynamic>> detections,
  });
}
