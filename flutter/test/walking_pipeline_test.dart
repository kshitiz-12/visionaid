import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/vision/domain/services/object_detector_service.dart';
import 'package:visionaid/features/walking/data/box_size_depth_provider.dart';
import 'package:visionaid/features/walking/data/free_space_analyzer.dart';
import 'package:visionaid/features/walking/data/walking_latency.dart';
import 'package:visionaid/features/walking/data/walking_pipeline.dart';
import 'package:visionaid/features/walking/data/walking_tracker.dart';
import 'package:visionaid/features/guide_alerts/domain/guide_models.dart';

RawDetection box({
  required String label,
  double left = 0.4,
  double width = 0.2,
  double top = 0.2,
  double height = 0.5,
  double confidence = 0.8,
  int? id,
  double? metres,
}) {
  return RawDetection(
    label: label,
    confidence: confidence,
    distance: width * height,
    boxLeft: left * 100,
    boxTop: top * 100,
    boxWidth: width * 100,
    boxHeight: height * 100,
    frameWidth: 100,
    frameHeight: 100,
    trackingId: id,
    distanceMeters: metres,
  );
}

void main() {
  test('corridor occupancy from a large center box', () {
    const space = FreeSpaceAnalyzer();
    final occ = space.evaluate(
      detections: [box(label: 'chair', width: 0.4, left: 0.3, metres: 0.9)],
      depth: BoxSizeDepthProvider(),
    );
    expect(occ.blocked, isTrue);
    expect(occ.namedLabel, 'chair');
  });

  test('side bottle does not block the corridor', () {
    const space = FreeSpaceAnalyzer();
    final occ = space.evaluate(
      detections: [box(label: 'bottle', left: 0.02, width: 0.08, metres: 0.7)],
      depth: BoxSizeDepthProvider(),
    );
    expect(occ.blocked, isFalse);
  });

  test('tracker treats shrinking metres as approaching', () {
    final tracker = WalkingTracker();
    final depth = BoxSizeDepthProvider();
    var now = DateTime(2026, 1, 1);
    tracker.update(
      detections: [box(label: 'car', id: 1, metres: 4)],
      depth: depth,
      now: now,
    );
    now = now.add(const Duration(milliseconds: 200));
    final later = tracker.update(
      detections: [box(label: 'car', id: 1, metres: 2)],
      depth: depth,
      now: now,
    );
    expect(later.single.movement, MovementState.approaching);
  });

  test('pipeline attaches approximate metres and keeps unknown obstacles', () {
    final pipeline = WalkingPipeline(depth: BoxSizeDepthProvider());
    final tick = pipeline.tick(
      raw: [box(label: 'obstacle', left: 0.36, width: 0.28, height: 0.7)],
      latency: WalkingLatency()
        ..frameCapturedMs = 0
        ..inferenceCompletedMs = 40,
    );
    expect(tick.snapshots, isNotEmpty);
    expect(tick.snapshots.first.distanceMeters, isNotNull);
    expect(tick.occupancy.blocked, isTrue);
  });

  test('spoken metres stay approximate', () {
    expect(BoxSizeDepthProvider.metresFromBoxFraction(0.45), greaterThan(0.4));
  });
}
