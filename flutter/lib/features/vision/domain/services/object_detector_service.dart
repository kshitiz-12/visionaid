import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class RawDetection {
  const RawDetection({
    required this.label,
    required this.confidence,
    required this.distance,
    this.isMoving = false,
    this.boxWidth = 0,
    this.boxHeight = 0,
    this.boxLeft = 0,
    this.boxTop = 0,
    this.frameWidth = 0,
    this.frameHeight = 0,
    this.trackingId,
    this.timestamp,
    this.distanceMeters,
  });

  final String label;
  final double confidence;

  /// Normalized proximity 0–1 from box size. Not meters.
  final double distance;
  final bool isMoving;
  final double boxWidth;
  final double boxHeight;
  final double boxLeft;
  final double boxTop;
  final double frameWidth;
  final double frameHeight;
  final int? trackingId;
  final DateTime? timestamp;

  /// Approximate metres when a depth provider filled it in. Null = unknown.
  final double? distanceMeters;

  RawDetection copyWith({
    String? label,
    double? confidence,
    double? distance,
    bool? isMoving,
    double? boxWidth,
    double? boxHeight,
    double? boxLeft,
    double? boxTop,
    double? frameWidth,
    double? frameHeight,
    int? trackingId,
    DateTime? timestamp,
    double? distanceMeters,
  }) {
    return RawDetection(
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      distance: distance ?? this.distance,
      isMoving: isMoving ?? this.isMoving,
      boxWidth: boxWidth ?? this.boxWidth,
      boxHeight: boxHeight ?? this.boxHeight,
      boxLeft: boxLeft ?? this.boxLeft,
      boxTop: boxTop ?? this.boxTop,
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      trackingId: trackingId ?? this.trackingId,
      timestamp: timestamp ?? this.timestamp,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

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
