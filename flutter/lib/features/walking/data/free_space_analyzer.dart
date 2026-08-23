import '../../guide_alerts/domain/guide_models.dart';
import '../../vision/domain/services/object_detector_service.dart';
import '../domain/depth_provider.dart';

class PathOccupancy {
  const PathOccupancy({
    required this.blocked,
    required this.closestMetres,
    required this.direction,
    required this.namedLabel,
  });

  final bool blocked;
  final double? closestMetres;
  final GuideDirection direction;
  final String namedLabel;
}

/// Walking corridor: center 35–65% of the frame.
class FreeSpaceAnalyzer {
  const FreeSpaceAnalyzer({
    this.corridorLeft = 0.35,
    this.corridorRight = 0.65,
    this.blockFraction = 0.16,
    this.closeMetres = 1.4,
  });

  final double corridorLeft;
  final double corridorRight;
  final double blockFraction;
  final double closeMetres;

  PathOccupancy evaluate({
    required List<RawDetection> detections,
    required DepthProvider depth,
  }) {
    var blocked = false;
    double? closest;
    var direction = GuideDirection.center;
    var named = '';

    for (final d in detections) {
      final fw = d.frameWidth <= 0 ? 1.0 : d.frameWidth;
      final fh = d.frameHeight <= 0 ? 1.0 : d.frameHeight;
      if (d.boxWidth <= 0) {
        continue;
      }
      final left = d.boxLeft / fw;
      final right = (d.boxLeft + d.boxWidth) / fw;
      final top = d.boxTop / fh;
      final bottom = (d.boxTop + d.boxHeight) / fh;
      final overlapLeft = left > corridorLeft ? left : corridorLeft;
      final overlapRight = right < corridorRight ? right : corridorRight;
      final overlap = overlapRight > overlapLeft ? overlapRight - overlapLeft : 0.0;
      final width = right - left;
      final frac = width <= 0 ? 0.0 : overlap / width;
      if (frac < 0.12 && d.distance < 0.22) {
        continue;
      }
      final inCorridor = frac >= 0.18 ||
          ((left + right) / 2 >= corridorLeft && (left + right) / 2 <= corridorRight);
      if (!inCorridor) {
        continue;
      }
      final metres = d.distanceMeters ??
          depth.distanceInRegion(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          );
      final close = d.distance >= blockFraction ||
          (metres != null && metres <= closeMetres);
      if (!close) {
        continue;
      }
      blocked = true;
      if (closest == null || (metres != null && metres < closest)) {
        closest = metres;
      }
      final cx = (left + right) / 2;
      direction = _dir(cx);
      if (d.label.isNotEmpty && d.label != 'object') {
        named = d.label;
      }
    }

    return PathOccupancy(
      blocked: blocked,
      closestMetres: closest,
      direction: direction,
      namedLabel: named,
    );
  }

  GuideDirection _dir(double cx) {
    if (cx < 0.20) {
      return GuideDirection.left;
    }
    if (cx < 0.40) {
      return GuideDirection.slightLeft;
    }
    if (cx < 0.60) {
      return GuideDirection.center;
    }
    if (cx < 0.80) {
      return GuideDirection.slightRight;
    }
    return GuideDirection.right;
  }
}
