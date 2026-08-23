import 'package:flutter/services.dart';

import '../domain/depth_provider.dart';
import 'box_size_depth_provider.dart';

/// Probes ARCore on Android. Depth samples stay on the box-size fallback until
/// an AR session can own the camera (not shared with Flutter CameraX).
class CompositeDepthProvider implements DepthProvider {
  CompositeDepthProvider({BoxSizeDepthProvider? fallback})
      : _fallback = fallback ?? BoxSizeDepthProvider();

  static const _channel = MethodChannel('visionaid/walking');

  final BoxSizeDepthProvider _fallback;
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
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('capabilities');
      final arcore = raw?['arcore'] == true;
      final depth = raw?['depth'] == true;
      capabilities = DepthCapabilities(
        arcoreAvailable: arcore,
        depthApiAvailable: depth,
        activeSource: depth ? 'arcore-probe+box-size' : 'box-size',
      );
    } catch (_) {
      capabilities = const DepthCapabilities(
        arcoreAvailable: false,
        depthApiAvailable: false,
        activeSource: 'box-size',
      );
    }
  }

  @override
  double? distanceAtPoint({required double nx, required double ny}) {
    return _fallback.distanceAtPoint(nx: nx, ny: ny);
  }

  @override
  double? distanceInRegion({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return _fallback.distanceInRegion(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }
}
