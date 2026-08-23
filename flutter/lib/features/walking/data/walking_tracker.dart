import '../../guide_alerts/domain/guide_models.dart';
import '../../vision/domain/services/object_detector_service.dart';
import '../domain/depth_provider.dart';

class TrackedObstacle {
  TrackedObstacle({
    required this.id,
    required this.label,
    required this.confidence,
    required this.boxLeft,
    required this.boxTop,
    required this.boxRight,
    required this.boxBottom,
    required this.centerX,
    required this.distanceMetres,
    required this.direction,
    required this.movement,
    required this.lastSeen,
  });

  final int id;
  String label;
  double confidence;
  double boxLeft;
  double boxTop;
  double boxRight;
  double boxBottom;
  double centerX;
  double? distanceMetres;
  double? previousMetres;
  GuideDirection direction;
  MovementState movement;
  DateTime lastSeen;
}

class WalkingTracker {
  WalkingTracker({this.iouThreshold = 0.28});

  final double iouThreshold;
  final Map<int, TrackedObstacle> _tracks = {};
  int _nextId = 1;

  List<TrackedObstacle> update({
    required List<RawDetection> detections,
    required DepthProvider depth,
    required DateTime now,
  }) {
    final used = <int>{};
    for (final d in detections) {
      final fw = d.frameWidth <= 0 ? 1.0 : d.frameWidth;
      final fh = d.frameHeight <= 0 ? 1.0 : d.frameHeight;
      final left = d.boxWidth <= 0 ? 0.0 : d.boxLeft / fw;
      final right = d.boxWidth <= 0 ? 0.0 : (d.boxLeft + d.boxWidth) / fw;
      final top = d.boxHeight <= 0 ? 0.0 : d.boxTop / fh;
      final bottom = d.boxHeight <= 0 ? 0.0 : (d.boxTop + d.boxHeight) / fh;
      final cx = (left + right) / 2;
      final metres = d.distanceMeters ??
          (d.boxWidth <= 0
              ? null
              : depth.distanceInRegion(
                  left: left,
                  top: top,
                  right: right,
                  bottom: bottom,
                ));

      TrackedObstacle? match;
      if (d.trackingId != null) {
        match = _tracks[d.trackingId!];
      }
      match ??= _bestIou(left, top, right, bottom, d.label, used);

      if (match == null) {
        final id = d.trackingId ?? _nextId++;
        match = TrackedObstacle(
          id: id,
          label: d.label,
          confidence: d.confidence,
          boxLeft: left,
          boxTop: top,
          boxRight: right,
          boxBottom: bottom,
          centerX: cx,
          distanceMetres: metres,
          direction: _dir(cx),
          movement: MovementState.unknown,
          lastSeen: now,
        );
        _tracks[id] = match;
      } else {
        match.previousMetres = match.distanceMetres;
        match.label = d.label.isNotEmpty ? d.label : match.label;
        match.confidence = d.confidence;
        match.boxLeft = left;
        match.boxTop = top;
        match.boxRight = right;
        match.boxBottom = bottom;
        match.centerX = cx;
        match.distanceMetres = metres;
        match.direction = _dir(cx);
        match.movement = _movement(
          previousMetres: match.previousMetres,
          metres: metres,
          previousX: match.centerX,
          centerX: cx,
        );
        match.lastSeen = now;
      }
      used.add(match.id);
    }

    _tracks.removeWhere(
      (id, t) => now.difference(t.lastSeen) > const Duration(milliseconds: 900),
    );
    return _tracks.values.toList();
  }

  TrackedObstacle? _bestIou(
    double l,
    double t,
    double r,
    double b,
    String label,
    Set<int> used,
  ) {
    TrackedObstacle? best;
    var bestIou = iouThreshold;
    for (final track in _tracks.values) {
      if (used.contains(track.id)) {
        continue;
      }
      if (label.isNotEmpty &&
          track.label.isNotEmpty &&
          track.label != label &&
          track.label != 'obstacle' &&
          label != 'obstacle') {
        continue;
      }
      final iou = _iou(l, t, r, b, track.boxLeft, track.boxTop, track.boxRight, track.boxBottom);
      if (iou >= bestIou) {
        bestIou = iou;
        best = track;
      }
    }
    return best;
  }

  MovementState _movement({
    required double? previousMetres,
    required double? metres,
    required double previousX,
    required double centerX,
  }) {
    final crossed = (centerX - previousX).abs() >= 0.18 &&
        ((previousX - 0.5).abs() > 0.08 && (centerX - 0.5).abs() <= 0.22 ||
            (centerX - 0.5).abs() > 0.08 && (previousX - 0.5).abs() <= 0.22);
    if (crossed) {
      return MovementState.crossingPath;
    }
    if (previousMetres == null || metres == null) {
      return MovementState.unknown;
    }
    final delta = previousMetres - metres;
    if (delta > 0.35) {
      return MovementState.approaching;
    }
    if (delta < -0.35) {
      return MovementState.movingAway;
    }
    if (delta.abs() < 0.12) {
      return MovementState.staticState;
    }
    return MovementState.moving;
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

  double _iou(
    double aL,
    double aT,
    double aR,
    double aB,
    double bL,
    double bT,
    double bR,
    double bB,
  ) {
    final l = aL > bL ? aL : bL;
    final t = aT > bT ? aT : bT;
    final r = aR < bR ? aR : bR;
    final b = aB < bB ? aB : bB;
    final w = r - l;
    final h = b - t;
    if (w <= 0 || h <= 0) {
      return 0;
    }
    final inter = w * h;
    final a = (aR - aL) * (aB - aT);
    final bb = (bR - bL) * (bB - bT);
    final union = a + bb - inter;
    if (union <= 0) {
      return 0;
    }
    return inter / union;
  }
}
