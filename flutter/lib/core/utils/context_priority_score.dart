double calculatePriorityScore({
  required double confidence,
  required double distance,
  required double motion,
  required double userIntent,
  required double objectImportance,
  required double navigationRisk,
}) {
  final normalizedConfidence = confidence.clamp(0.0, 1.0);
  final normalizedDistance = distance.clamp(0.0, 1.0);
  final normalizedMotion = motion.clamp(0.0, 1.0);
  final normalizedUserIntent = userIntent.clamp(0.0, 1.0);
  final normalizedObjectImportance = objectImportance.clamp(0.0, 1.0);
  final normalizedNavigationRisk = navigationRisk.clamp(0.0, 1.0);

  final weightedScore =
      normalizedConfidence * 1.0 +
      normalizedDistance * 0.8 +
      normalizedMotion * 0.9 +
      normalizedUserIntent * 1.1 +
      normalizedObjectImportance * 1.0 +
      normalizedNavigationRisk * 1.2;

  return weightedScore * 0.9;
}
