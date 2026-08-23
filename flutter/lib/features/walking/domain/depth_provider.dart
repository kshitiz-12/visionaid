/// Depth for walking. Implementations must not call the network.
abstract class DepthProvider {
  String get sourceId;

  bool get isApproximate;

  Future<void> warmup();

  /// Metres at a normalized image point (0–1), or null if unknown.
  double? distanceAtPoint({required double nx, required double ny});

  /// Closest metres in a normalized rectangle, or null.
  double? distanceInRegion({
    required double left,
    required double top,
    required double right,
    required double bottom,
  });
}

class DepthCapabilities {
  const DepthCapabilities({
    required this.arcoreAvailable,
    required this.depthApiAvailable,
    required this.activeSource,
  });

  final bool arcoreAvailable;
  final bool depthApiAvailable;
  final String activeSource;
}
