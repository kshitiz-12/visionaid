import '../../guide_alerts/domain/guide_models.dart';
import '../../vision/domain/services/object_detector_service.dart';
import '../domain/depth_provider.dart';
import 'composite_depth_provider.dart';
import 'free_space_analyzer.dart';
import 'walking_latency.dart';
import 'walking_tracker.dart';

class WalkingTick {
  const WalkingTick({
    required this.snapshots,
    required this.occupancy,
    required this.tracks,
    required this.latency,
    required this.fps,
  });

  final List<GuideObjectSnapshot> snapshots;
  final PathOccupancy occupancy;
  final List<TrackedObstacle> tracks;
  final WalkingLatency latency;
  final double fps;
}

/// Local walking perception after a frame has already been classified.
class WalkingPipeline {
  WalkingPipeline({
    DepthProvider? depth,
    WalkingTracker? tracker,
    FreeSpaceAnalyzer? freeSpace,
  })  : depth = depth ?? CompositeDepthProvider(),
        tracker = tracker ?? WalkingTracker(),
        freeSpace = freeSpace ?? const FreeSpaceAnalyzer();

  final DepthProvider depth;
  final WalkingTracker tracker;
  final FreeSpaceAnalyzer freeSpace;

  int _frames = 0;
  DateTime? _fpsAt;
  double fps = 0;

  Future<void> warmup() => depth.warmup();

  WalkingTick tick({
    required List<RawDetection> raw,
    required WalkingLatency latency,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    _noteFps(t);

    final withMetres = raw.map(_withMetres).toList();
    latency.depthCompletedMs = DateTime.now().millisecondsSinceEpoch;

    final occupancy = freeSpace.evaluate(
      detections: withMetres,
      depth: depth,
    );

    final tracks = tracker.update(
      detections: withMetres,
      depth: depth,
      now: t,
    );
    latency.trackingCompletedMs = DateTime.now().millisecondsSinceEpoch;

    final snapshots = _snapshots(withMetres, tracks, occupancy);
    return WalkingTick(
      snapshots: snapshots,
      occupancy: occupancy,
      tracks: tracks,
      latency: latency,
      fps: fps,
    );
  }

  RawDetection _withMetres(RawDetection d) {
    if (d.distanceMeters != null) {
      return d;
    }
    final fw = d.frameWidth <= 0 ? 1.0 : d.frameWidth;
    final fh = d.frameHeight <= 0 ? 1.0 : d.frameHeight;
    if (d.boxWidth <= 0) {
      return d;
    }
    final metres = depth.distanceInRegion(
      left: d.boxLeft / fw,
      top: d.boxTop / fh,
      right: (d.boxLeft + d.boxWidth) / fw,
      bottom: (d.boxTop + d.boxHeight) / fh,
    );
    return d.copyWith(distanceMeters: metres);
  }

  List<GuideObjectSnapshot> _snapshots(
    List<RawDetection> detections,
    List<TrackedObstacle> tracks,
    PathOccupancy occupancy,
  ) {
    final byId = {for (final t in tracks) t.id: t};
    final snaps = <GuideObjectSnapshot>[];
    final used = <int>{};

    for (final d in detections) {
      TrackedObstacle? track;
      if (d.trackingId != null) {
        track = byId[d.trackingId!];
      }
      track ??= _nearestTrack(d, tracks, used);
      if (track != null) {
        used.add(track.id);
        snaps.add(_fromTrack(track, d));
      } else {
        snaps.add(_fromDetection(d));
      }
    }

    if (occupancy.blocked && !_hasCorridorBlock(snaps)) {
      snaps.add(
        GuideObjectSnapshot(
          label: occupancy.namedLabel.isEmpty ? 'obstacle' : occupancy.namedLabel,
          confidence: 0.82,
          boundingBox: (left: 0.35, top: 0.20, right: 0.65, bottom: 0.95),
          centerX: 0.5,
          centerY: 0.55,
          distanceMeters: occupancy.closestMetres,
          direction: occupancy.direction,
          movementState: MovementState.unknown,
          trackingId: 900001,
          boxProximity: 0.50,
        ),
      );
    }
    return snaps;
  }

  bool _hasCorridorBlock(List<GuideObjectSnapshot> snaps) {
    for (final s in snaps) {
      final x = s.centerX ?? 0.5;
      final close = (s.distanceMeters != null && s.distanceMeters! <= 1.4) ||
          s.boxProximity >= 0.16;
      if (x >= 0.35 && x <= 0.65 && close) {
        return true;
      }
    }
    return false;
  }

  TrackedObstacle? _nearestTrack(
    RawDetection d,
    List<TrackedObstacle> tracks,
    Set<int> used,
  ) {
    final fw = d.frameWidth <= 0 ? 1.0 : d.frameWidth;
    final cx = d.boxWidth <= 0 ? 0.5 : (d.boxLeft + d.boxWidth / 2) / fw;
    TrackedObstacle? best;
    var bestD = 0.18;
    for (final t in tracks) {
      if (used.contains(t.id)) {
        continue;
      }
      if (t.label != d.label && t.label != 'obstacle' && d.label != 'obstacle') {
        continue;
      }
      final delta = (t.centerX - cx).abs();
      if (delta < bestD) {
        bestD = delta;
        best = t;
      }
    }
    return best;
  }

  GuideObjectSnapshot _fromTrack(TrackedObstacle t, RawDetection d) {
    return GuideObjectSnapshot(
      label: t.label,
      confidence: t.confidence,
      boundingBox: (
        left: t.boxLeft,
        top: t.boxTop,
        right: t.boxRight,
        bottom: t.boxBottom,
      ),
      centerX: t.centerX,
      distanceMeters: t.distanceMetres ?? d.distanceMeters,
      direction: t.direction,
      movementState: t.movement,
      trackingId: t.id,
      timestamp: d.timestamp,
      isMoving: t.movement == MovementState.approaching ||
          t.movement == MovementState.moving ||
          t.movement == MovementState.crossingPath,
      boxProximity: d.distance,
    );
  }

  GuideObjectSnapshot _fromDetection(RawDetection d) {
    final fw = d.frameWidth <= 0 ? 1.0 : d.frameWidth;
    final fh = d.frameHeight <= 0 ? 1.0 : d.frameHeight;
    final left = d.boxWidth <= 0 ? 0.0 : d.boxLeft / fw;
    final right = d.boxWidth <= 0 ? 0.0 : (d.boxLeft + d.boxWidth) / fw;
    final top = d.boxHeight <= 0 ? 0.0 : d.boxTop / fh;
    final bottom = d.boxHeight <= 0 ? 0.0 : (d.boxTop + d.boxHeight) / fh;
    final cx = (left + right) / 2;
    return GuideObjectSnapshot(
      label: d.label,
      confidence: d.confidence,
      boundingBox: d.boxWidth <= 0
          ? null
          : (left: left, top: top, right: right, bottom: bottom),
      centerX: d.boxWidth <= 0 ? null : cx,
      distanceMeters: d.distanceMeters,
      trackingId: d.trackingId,
      timestamp: d.timestamp,
      isMoving: d.isMoving,
      boxProximity: d.distance,
    );
  }

  void _noteFps(DateTime t) {
    _frames += 1;
    _fpsAt ??= t;
    final elapsed = t.difference(_fpsAt!).inMilliseconds;
    if (elapsed >= 1000) {
      fps = _frames * 1000 / elapsed;
      _frames = 0;
      _fpsAt = t;
    }
  }
}
