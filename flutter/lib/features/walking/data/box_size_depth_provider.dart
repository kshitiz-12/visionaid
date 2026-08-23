import '../domain/depth_provider.dart';

/// Box-size fallback. Not a tape measure.
class BoxSizeDepthProvider implements DepthProvider {
  @override
  String get sourceId => 'box-size';

  @override
  bool get isApproximate => true;

  @override
  Future<void> warmup() async {}

  @override
  double? distanceAtPoint({required double nx, required double ny}) => null;

  @override
  double? distanceInRegion({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final w = (right - left).clamp(0.0, 1.0);
    final h = (bottom - top).clamp(0.0, 1.0);
    return metresFromBoxFraction(w * h);
  }

  static double metresFromBoxFraction(double fraction) {
    final f = fraction.clamp(0.02, 0.95);
    final metres = 0.45 / f;
    return metres.clamp(0.4, 6.0);
  }
}
