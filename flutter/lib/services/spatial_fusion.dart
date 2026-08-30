import 'dart:typed_data';

/// Raised when YOLO×MiDaS spatial fusion cannot produce a valid vector.
class SpatialFusionException implements Exception {
  const SpatialFusionException(this.message, {this.code = 'SPATIAL_FUSION'});

  final String message;
  final String code;

  @override
  String toString() => 'SpatialFusionException($code): $message';
}

class SpatialFusionConfigException extends SpatialFusionException {
  const SpatialFusionConfigException(super.message)
      : super(code: 'SPATIAL_FUSION_CONFIG');
}

class SpatialFusionDimensionException extends SpatialFusionException {
  const SpatialFusionDimensionException(super.message)
      : super(code: 'SPATIAL_FUSION_DIMENSION');
}

class SpatialFusionBoundsException extends SpatialFusionException {
  const SpatialFusionBoundsException(super.message)
      : super(code: 'SPATIAL_FUSION_BOUNDS');
}

class SpatialFusionDepthException extends SpatialFusionException {
  const SpatialFusionDepthException(super.message)
      : super(code: 'SPATIAL_FUSION_DEPTH');
}

/// How values in the MiDaS (or compatible) depth buffer are encoded.
enum DepthMapEncoding {
  /// Normalized inverse depth in \[0, 1\] (near → 1). Matches VisionAid MiDaS TFLite.
  normalizedInverse,
}

/// Converts relative MiDaS values into approximate metres.
///
/// Monocular MiDaS is not metrically absolute without camera calibration.
/// Callers must supply [scaleMeters] explicitly (no silent defaults inside
/// [SpatialFusion.computeVector]).
class DepthMetricCalibration {
  const DepthMetricCalibration({
    required this.scaleMeters,
    this.minMetres = 0.35,
    this.maxMetres = 8.0,
    this.inverseEpsilon = 0.08,
  })  : assert(scaleMeters > 0),
        assert(minMetres > 0),
        assert(maxMetres > minMetres),
        assert(inverseEpsilon > 0);

  /// Used as `Z = scaleMeters / max(inverseEpsilon, inverseDepth)`.
  final double scaleMeters;
  final double minMetres;
  final double maxMetres;
  final double inverseEpsilon;

  /// Calibration aligned with VisionAid MiDaS (continuous metric scaling).
  static const visionAidMidasSmall = DepthMetricCalibration(
    scaleMeters: 1.0,
    minMetres: 0.3,
    maxMetres: 5.0,
    inverseEpsilon: 0.05,
  );

  /// Continuous metric depth:
  /// `Z = focalScale / (rawDepth * 0.01 + 0.05)` clamped to [minMetres, maxMetres].
  ///
  /// For normalized inverse maps in \[0,1\], [rawDepth] is `inverse * 100`
  /// so near objects (high inverse) map to smaller Z.
  double metresFromInverse(double inverseDepth) {
    if (inverseDepth.isNaN || inverseDepth.isInfinite) {
      throw SpatialFusionDepthException(
        'Inverse-depth sample is not finite (got $inverseDepth).',
      );
    }
    if (inverseDepth < 0 || inverseDepth > 1) {
      throw SpatialFusionDepthException(
        'Normalized inverse-depth must be in [0, 1] (got $inverseDepth).',
      );
    }
    final rawDepth = inverseDepth * 100.0;
    final z = scaleMeters / (rawDepth * 0.01 + inverseEpsilon);
    return z.clamp(minMetres, maxMetres);
  }
}

/// Axis-aligned box in **normalized camera-frame coordinates** (0..1).
class NormalizedBoundingBox {
  const NormalizedBoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  double get width => x2 - x1;
  double get height => y2 - y1;
  double get centerX => (x1 + x2) / 2.0;
  double get centerY => (y1 + y2) / 2.0;

  void validate() {
    for (final value in [x1, y1, x2, y2]) {
      if (value.isNaN || value.isInfinite) {
        throw const SpatialFusionBoundsException(
          'Bounding box coordinates must be finite.',
        );
      }
    }
    if (x1 < 0 || y1 < 0 || x2 > 1 || y2 > 1) {
      throw SpatialFusionBoundsException(
        'Bounding box must lie in [0,1]×[0,1] '
        '(got [$x1, $y1, $x2, $y2]).',
      );
    }
    if (x2 <= x1 || y2 <= y1) {
      throw SpatialFusionBoundsException(
        'Bounding box requires x2 > x1 and y2 > y1 '
        '(got [$x1, $y1, $x2, $y2]).',
      );
    }
    if (width < 1e-4 || height < 1e-4) {
      throw SpatialFusionBoundsException(
        'Bounding box is degenerate (width=$width, height=$height).',
      );
    }
  }
}

/// Structured YOLO×depth vector for downstream audio / memory.
class SpatialVector {
  const SpatialVector({
    required this.label,
    required this.depthZMeters,
    required this.angleXDegrees,
    required this.centerXNorm,
    required this.centerYNorm,
    required this.meanInverseDepth,
    required this.sampleCount,
    required this.summary,
    this.boxArea,
    this.closeRangeOverride = false,
  });

  final String label;

  /// Metric depth \(Z\) in metres (approximate under [DepthMetricCalibration]).
  final double depthZMeters;

  /// Relative horizontal angle \(X\) in degrees, clamped to \([-30, +30]\).
  /// Negative = left of center, positive = right of center.
  final double angleXDegrees;

  final double centerXNorm;
  final double centerYNorm;
  final double meanInverseDepth;
  final int sampleCount;

  /// Normalized frame coverage of the detection box (0..1).
  final double? boxArea;

  /// True when frame-area override replaced metric depth (lap / filling view).
  final bool closeRangeOverride;

  /// e.g. `"Stairs 1.2 meters ahead, 15 degrees right"`.
  final String summary;

  Map<String, Object?> toMetricsMap() => {
        'label': label,
        'depth_z_meters': depthZMeters,
        'angle_x_degrees': angleXDegrees,
        'center_x_norm': centerXNorm,
        'center_y_norm': centerYNorm,
        'mean_inverse_depth': meanInverseDepth,
        'sample_count': sampleCount,
        'summary': summary,
        'box_area': boxArea,
        'close_range_override': closeRangeOverride,
      };
}

/// Fuses a YOLO box with a MiDaS depth matrix into metric \(Z\) and angle \(X\).
class SpatialFusion {
  SpatialFusion({
    required DepthMetricCalibration calibration,
    this.encoding = DepthMapEncoding.normalizedInverse,
    this.horizontalHalfFovDegrees = 30.0,
  }) : _calibration = calibration {
    if (horizontalHalfFovDegrees <= 0 || horizontalHalfFovDegrees > 90) {
      throw SpatialFusionConfigException(
        'horizontalHalfFovDegrees must be in (0, 90] '
        '(got $horizontalHalfFovDegrees).',
      );
    }
  }

  final DepthMetricCalibration _calibration;
  final DepthMapEncoding encoding;

  /// Half horizontal FOV used to map box center → degrees.
  /// With 30°, full frame width maps to \([-30°, +30°]\).
  final double horizontalHalfFovDegrees;

  /// Combines [box] with [depthMap] into a [SpatialVector].
  ///
  /// [depthMap] must be row-major with length `mapWidth * mapHeight`.
  /// [box] is normalized to the camera frame (same aspect the depth map covers).
  ///
  /// When frame coverage [boxArea] > [closeRangeAreaThreshold], metric depth is
  /// bypassed ("very close / in your lap") — laptop-on-lap must not say "1 metre".
  static const closeRangeAreaThreshold = 0.40;
  static const closeRangeDepthMetres = 0.35;

  SpatialVector computeVector({
    required String label,
    required Float32List depthMap,
    required int mapWidth,
    required int mapHeight,
    required NormalizedBoundingBox box,
  }) {
    final name = label.trim();
    if (name.isEmpty) {
      throw const SpatialFusionConfigException(
        'computeVector requires a non-empty label.',
      );
    }
    if (mapWidth <= 0 || mapHeight <= 0) {
      throw SpatialFusionDimensionException(
        'Depth map dimensions must be positive '
        '(got ${mapWidth}x$mapHeight).',
      );
    }
    final expected = mapWidth * mapHeight;
    if (depthMap.length != expected) {
      throw SpatialFusionDimensionException(
        'Depth map length ${depthMap.length} does not match '
        'mapWidth*mapHeight=$expected (${mapWidth}x$mapHeight).',
      );
    }
    if (encoding != DepthMapEncoding.normalizedInverse) {
      throw SpatialFusionConfigException(
        'Unsupported DepthMapEncoding: $encoding',
      );
    }

    box.validate();
    final area = (box.width * box.height).clamp(0.0, 1.0);
    if (area < 0.004) {
      throw SpatialFusionBoundsException(
        'Bounding box area $area is too small for stable fusion.',
      );
    }

    final angle = _angleFromCenterX(box.centerX);
    final closeRange = area > closeRangeAreaThreshold;

    if (closeRange) {
      final summary = formatSummary(
        label: name,
        depthZMeters: closeRangeDepthMetres,
        angleXDegrees: angle,
        boxArea: area,
        hindi: false,
      );
      return SpatialVector(
        label: name,
        depthZMeters: closeRangeDepthMetres,
        angleXDegrees: angle,
        centerXNorm: box.centerX,
        centerYNorm: box.centerY,
        meanInverseDepth: 1.0,
        sampleCount: 0,
        summary: summary,
        boxArea: area,
        closeRangeOverride: true,
      );
    }

    final meanInv = _meanInverseInBox(
      depthMap: depthMap,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      box: box,
    );
    final z = _calibration.metresFromInverse(meanInv.mean);
    final summary = formatSummary(
      label: name,
      depthZMeters: z,
      angleXDegrees: angle,
      boxArea: area,
    );

    return SpatialVector(
      label: name,
      depthZMeters: z,
      angleXDegrees: angle,
      centerXNorm: box.centerX,
      centerYNorm: box.centerY,
      meanInverseDepth: meanInv.mean,
      sampleCount: meanInv.count,
      summary: summary,
      boxArea: area,
      closeRangeOverride: false,
    );
  }

  /// Convenience for YOLO-style absolute pixel boxes on a source frame that
  /// was letterboxed/resized onto the depth map extent.
  SpatialVector computeVectorFromPixelBox({
    required String label,
    required Float32List depthMap,
    required int mapWidth,
    required int mapHeight,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double frameWidth,
    required double frameHeight,
  }) {
    if (frameWidth <= 0 || frameHeight <= 0) {
      throw SpatialFusionDimensionException(
        'frameWidth/frameHeight must be positive '
        '(got ${frameWidth}x$frameHeight).',
      );
    }
    return computeVector(
      label: label,
      depthMap: depthMap,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      box: NormalizedBoundingBox(
        x1: x1 / frameWidth,
        y1: y1 / frameHeight,
        x2: x2 / frameWidth,
        y2: y2 / frameHeight,
      ),
    );
  }

  /// Builds the spoken/log summary used by audio engines.
  ///
  /// Frame area > [closeRangeAreaThreshold] → "very close / in your lap",
  /// never a rigid "1 metre" guess.
  static String formatSummary({
    required String label,
    required double depthZMeters,
    required double angleXDegrees,
    double? boxArea,
    bool hindi = false,
  }) {
    final name = label.trim();
    if (name.isEmpty) {
      throw const SpatialFusionConfigException(
        'formatSummary requires a non-empty label.',
      );
    }
    if (depthZMeters.isNaN || depthZMeters.isInfinite || depthZMeters <= 0) {
      throw SpatialFusionDepthException(
        'formatSummary depthZMeters must be a positive finite metre value '
        '(got $depthZMeters).',
      );
    }
    if (angleXDegrees.isNaN || angleXDegrees.isInfinite) {
      throw SpatialFusionBoundsException(
        'formatSummary angleXDegrees must be finite (got $angleXDegrees).',
      );
    }

    if (boxArea != null && boxArea > closeRangeAreaThreshold) {
      final close = hindi
          ? 'बहुत पास / आपकी गोद में'
          : 'very close / in your lap';
      return '$name $close';
    }

    final depthText = _continuousDepthPhrase(depthZMeters, boxArea: boxArea);
    final absAngle = angleXDegrees.abs().round();
    if (absAngle < 3) {
      return '$name $depthText ahead';
    }
    final side = angleXDegrees < 0 ? 'left' : 'right';
    return '$name $depthText ahead, $absAngle degrees $side';
  }

  static String _continuousDepthPhrase(double z, {double? boxArea}) {
    if (boxArea != null && boxArea > SpatialFusion.closeRangeAreaThreshold) {
      return 'very close / in your lap';
    }
    if (boxArea != null && boxArea >= 0.80) {
      return 'very close, filling the view';
    }
    if (z < 0.55) {
      return 'very close';
    }
    if (z < 0.9) {
      return 'close, about ${(z * 100).round()} centimeters';
    }
    if (z < 1.4) {
      return 'about ${_oneDecimal(z)} meters';
    }
    if (z < 2.6) {
      return 'about ${_oneDecimal(z)} meters';
    }
    return 'farther, about ${_oneDecimal(z)} meters';
  }

  double _angleFromCenterX(double centerXNorm) {
    // Map [0,1] → [-halfFov, +halfFov]. Full width = 2 * halfFov.
    final angle = (centerXNorm - 0.5) * (2.0 * horizontalHalfFovDegrees);
    return angle.clamp(-horizontalHalfFovDegrees, horizontalHalfFovDegrees);
  }

  ({double mean, int count}) _meanInverseInBox({
    required Float32List depthMap,
    required int mapWidth,
    required int mapHeight,
    required NormalizedBoundingBox box,
  }) {
    final x0 = (box.x1 * (mapWidth - 1)).floor().clamp(0, mapWidth - 1);
    final x1 = (box.x2 * (mapWidth - 1)).ceil().clamp(0, mapWidth - 1);
    final y0 = (box.y1 * (mapHeight - 1)).floor().clamp(0, mapHeight - 1);
    final y1 = (box.y2 * (mapHeight - 1)).ceil().clamp(0, mapHeight - 1);
    if (x1 < x0 || y1 < y0) {
      throw SpatialFusionBoundsException(
        'Bounding box maps to an empty depth region '
        '(px=[$x0,$y0]-[$x1,$y1] on ${mapWidth}x$mapHeight).',
      );
    }

    var sum = 0.0;
    var count = 0;
    for (var y = y0; y <= y1; y++) {
      final row = y * mapWidth;
      for (var x = x0; x <= x1; x++) {
        final v = depthMap[row + x];
        if (v.isNaN || v.isInfinite) {
          throw SpatialFusionDepthException(
            'Non-finite depth at ($x,$y): $v',
          );
        }
        if (v < 0 || v > 1) {
          throw SpatialFusionDepthException(
            'Depth at ($x,$y)=$v outside normalized inverse range [0,1].',
          );
        }
        sum += v;
        count += 1;
      }
    }
    if (count == 0) {
      throw const SpatialFusionDepthException(
        'No depth samples collected inside bounding box.',
      );
    }
    return (mean: sum / count, count: count);
  }

  static String _oneDecimal(double metres) {
    final rounded = (metres * 10).round() / 10.0;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(1);
  }
}
