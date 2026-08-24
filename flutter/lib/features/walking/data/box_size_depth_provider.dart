import '../domain/depth_provider.dart';

/// Ground-plane + box-height fallback. Not a tape measure.
///
/// Objects whose bounding box sits near the bottom of the frame are closer
/// to the user's feet. Shorter mid-frame boxes are treated as table-level.
class BoxSizeDepthProvider implements DepthProvider {
  @override
  String get sourceId => 'ground-plane';

  @override
  bool get isApproximate => true;

  @override
  Future<void> warmup() async {}

  @override
  double? distanceAtPoint({required double nx, required double ny}) {
    return metresFromFootY(ny);
  }

  @override
  double? distanceInRegion({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return metresFromBox(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  /// Inverse mapping: foot-line near the bottom of the image → closer.
  static double metresFromFootY(double footY) {
    final t = footY.clamp(0.22, 0.98);
    return (0.38 / (t - 0.16)).clamp(0.4, 6.0);
  }

  /// Tall boxes in the frame are nearer; used for table-top items.
  static double metresFromHeightRatio(double heightRatio) {
    final h = heightRatio.clamp(0.04, 0.95);
    return (0.42 / h).clamp(0.4, 5.5);
  }

  static double metresFromBox({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final footY = bottom.clamp(0.0, 1.0);
    final height = (bottom - top).clamp(0.02, 1.0);
    final ground = metresFromFootY(footY);
    final table = metresFromHeightRatio(height);
    final onGround = footY >= 0.62 || height >= 0.38;
    if (onGround) {
      return ground;
    }
    return (table * 0.7 + ground * 0.3).clamp(0.4, 6.0);
  }

  /// Kept for older area-based callers/tests.
  static double metresFromBoxFraction(double fraction) {
    final f = fraction.clamp(0.02, 0.95);
    return (0.45 / f).clamp(0.4, 6.0);
  }
}
