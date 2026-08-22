class PrioritizedObject {
  const PrioritizedObject({
    required this.label,
    required this.confidence,
    required this.distance,
    required this.isMoving,
    required this.importance,
    required this.navigationRisk,
    required this.userIntentMatch,
    required this.priorityScore,
  });

  final String label;
  final double confidence;

  /// 0 = far, 1 = very close (normalized proximity).
  final double distance;
  final bool isMoving;
  final double importance;
  final double navigationRisk;
  final double userIntentMatch;
  final double priorityScore;

  bool get isHazard =>
      navigationRisk >= 0.6 ||
      label.contains('car') ||
      label.contains('truck') ||
      label.contains('bus') ||
      label.contains('motorcycle') ||
      label.contains('bicycle');

  Map<String, dynamic> toMap() => {
        'label': label,
        'confidence': confidence,
        'distance': distance,
        'isMoving': isMoving,
        'importance': importance,
        'navigationRisk': navigationRisk,
        'userIntentMatch': userIntentMatch,
        'priorityScore': priorityScore,
      };
}
