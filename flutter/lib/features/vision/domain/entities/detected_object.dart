import '../../../../core/utils/context_priority_score.dart';

class DetectedObject {
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.distance,
    required this.isMoving,
    required this.importance,
    required this.navigationRisk,
  });

  final String label;
  final double confidence;
  final double distance;
  final bool isMoving;
  final double importance;
  final double navigationRisk;

  double get priorityScore => calculatePriorityScore(
        confidence: confidence,
        distance: distance,
        motion: isMoving ? 1.0 : 0.2,
        userIntent: 0.9,
        objectImportance: importance,
        navigationRisk: navigationRisk,
      );

  bool get isHazard => navigationRisk >= 0.6 || label.toLowerCase().contains('vehicle');
}
