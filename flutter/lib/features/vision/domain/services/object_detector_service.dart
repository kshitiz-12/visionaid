import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class RawDetection {
  const RawDetection({
    required this.label,
    required this.confidence,
    required this.distance,
    this.isMoving = false,
    this.boxWidth = 0,
    this.boxHeight = 0,
  });

  final String label;
  final double confidence;

  /// Normalized proximity 0–1 (larger box ≈ closer).
  final double distance;
  final bool isMoving;
  final double boxWidth;
  final double boxHeight;

  Map<String, dynamic> toMap() => {
        'label': label,
        'confidence': confidence,
        'distance': distance,
        'isMoving': isMoving,
      };
}

abstract class ObjectDetectorService {
  Future<List<RawDetection>> detect(String imagePath);
  Future<List<RawDetection>> detectInput(InputImage image);
  Future<void> dispose();
}
