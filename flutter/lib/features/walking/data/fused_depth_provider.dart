import '../domain/depth_provider.dart';
import 'box_size_depth_provider.dart';
import 'monocular_depth_estimator.dart';

/// Fuses box-size priors with optional MiDaS relative depth when available.
class FusedDepthProvider implements DepthProvider {
  FusedDepthProvider({
    BoxSizeDepthProvider? fallback,
    MonocularDepthEstimator? midas,
  })  : _fallback = fallback ?? BoxSizeDepthProvider(),
        midas = midas ?? MonocularDepthEstimator();

  final BoxSizeDepthProvider _fallback;
  final MonocularDepthEstimator midas;

  DepthCapabilities capabilities = const DepthCapabilities(
    arcoreAvailable: false,
    depthApiAvailable: false,
    activeSource: 'box-size',
  );

  @override
  String get sourceId => capabilities.activeSource;

  @override
  bool get isApproximate => true;

  @override
  Future<void> warmup() async {
    final hasMidas = await midas.warmup();
    capabilities = DepthCapabilities(
      arcoreAvailable: false,
      depthApiAvailable: hasMidas,
      activeSource: hasMidas ? 'midas+box-size' : 'box-size',
    );
  }

  @override
  double? distanceAtPoint({required double nx, required double ny}) {
    final box = _fallback.distanceAtPoint(nx: nx, ny: ny) ?? 2.0;
    final fused = midas.metresInRegion(
      left: (nx - 0.02).clamp(0.0, 1.0),
      top: (ny - 0.02).clamp(0.0, 1.0),
      right: (nx + 0.02).clamp(0.0, 1.0),
      bottom: (ny + 0.02).clamp(0.0, 1.0),
      boxFallbackMetres: box,
    );
    return fused ?? box;
  }

  @override
  double? distanceInRegion({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final box = _fallback.distanceInRegion(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ) ??
        2.0;
    final fused = midas.metresInRegion(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      boxFallbackMetres: box,
    );
    return fused ?? box;
  }

  Future<void> dispose() => midas.dispose();
}
