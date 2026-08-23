import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/guide_alerts/data/guide_alert_engine.dart';
import 'package:visionaid/features/guide_alerts/data/object_priority_engine.dart';
import 'package:visionaid/features/guide_alerts/data/target_search_service.dart';
import 'package:visionaid/features/guide_alerts/domain/guide_config.dart';
import 'package:visionaid/features/guide_alerts/domain/guide_models.dart';

void main() {
  const config = GuideConfig();
  const scoring = ObjectPriorityEngine(config);

  test('bottle example ≈ 32.7 SUPPRESS', () {
    final score = scoring.priorityScore(
      const PriorityFactors(
        confidence: 0.96,
        riskScore: 0.10,
        pathScore: 0.10,
        distanceScore: 0.40,
        movementScore: 0.10,
        intentScore: 0.00,
        noveltyScore: 0.50,
      ),
    );
    expect(score, closeTo(32.7, 0.05));
    expect(scoring.bandFor(score), PriorityBand.suppress);
  });

  test('chair example ≈ 60.5 ANNOUNCE', () {
    final score = scoring.priorityScore(
      const PriorityFactors(
        confidence: 0.95,
        riskScore: 0.20,
        pathScore: 0.90,
        distanceScore: 0.90,
        movementScore: 0.10,
        intentScore: 0.00,
        noveltyScore: 1.00,
      ),
    );
    expect(score, closeTo(60.5, 0.05));
    expect(scoring.bandFor(score), PriorityBand.announce);
  });

  test('stairs example ≈ 73.3 HIGH PRIORITY', () {
    final score = scoring.priorityScore(
      const PriorityFactors(
        confidence: 0.84,
        riskScore: 0.90,
        pathScore: 0.95,
        distanceScore: 0.90,
        movementScore: 0.10,
        intentScore: 0.00,
        noveltyScore: 1.00,
      ),
    );
    expect(score, closeTo(73.3, 0.05));
    expect(scoring.bandFor(score), PriorityBand.announce);
  });

  test('approaching vehicle example ≈ 77.15 HIGH PRIORITY', () {
    final score = scoring.priorityScore(
      const PriorityFactors(
        confidence: 0.82,
        riskScore: 0.90,
        pathScore: 0.95,
        distanceScore: 0.75,
        movementScore: 0.85,
        intentScore: 0.00,
        noveltyScore: 0.80,
      ),
    );
    expect(score, closeTo(77.15, 0.05));
    expect(scoring.bandFor(score), PriorityBand.highPriority);
  });

  GuideObjectSnapshot centerObject({
    required String label,
    required double confidence,
    MovementState movement = MovementState.unknown,
    double? meters,
    int? id,
  }) {
    return GuideObjectSnapshot(
      label: label,
      confidence: confidence,
      boundingBox: (left: 0.36, top: 0.2, right: 0.64, bottom: 0.8),
      centerX: 0.5,
      centerY: 0.5,
      distanceMeters: meters,
      direction: GuideDirection.center,
      movementState: movement,
      trackingId: id ?? 1,
      boxProximity: 0.8,
    );
  }

  List<GuideAnnouncement> pump(
    GuideAlertEngine engine, {
    required List<GuideObjectSnapshot> objects,
    required GuideMode mode,
    String target = '',
    int frames = 3,
  }) {
    FrameAlertResult last = const FrameAlertResult(announcements: []);
    for (var i = 0; i < frames; i++) {
      last = engine.evaluateSnapshots(
        snapshots: objects,
        mode: mode,
        findTarget: target,
      );
    }
    return last.announcements;
  }

  test('critical safety event → safety override', () {
    final engine = GuideAlertEngine();
    final objects = [
      centerObject(
        label: 'car',
        confidence: 0.82,
        movement: MovementState.approaching,
        meters: 1.2,
      ),
    ];
    final spoken = pump(engine, objects: objects, mode: GuideMode.liveGuide, frames: 1);
    expect(spoken, isNotEmpty);
    expect(spoken.first.safetyOverride, isTrue);
    expect(spoken.first.decision, AnnouncementDecision.announceSafety);
  });

  test('repeated object → cooldown suppression', () {
    var t = DateTime(2026, 1, 1, 12, 0, 0);
    final engine = GuideAlertEngine(clock: () => t);
    final objects = [
      centerObject(label: 'chair', confidence: 0.95, meters: 0.8, id: 7),
    ];
    final first = pump(engine, objects: objects, mode: GuideMode.liveGuide, frames: 1);
    expect(first, isNotEmpty);
    t = t.add(const Duration(milliseconds: 200));
    final again = engine.evaluateSnapshots(
      snapshots: objects,
      mode: GuideMode.liveGuide,
    );
    expect(again.announcements, isEmpty);
  });

  test('object becomes closer → new announcement', () {
    var t = DateTime(2026, 1, 1, 12, 0, 0);
    final engine = GuideAlertEngine(clock: () => t);
    final far = [
      GuideObjectSnapshot(
        label: 'car',
        confidence: 0.9,
        boundingBox: (left: 0.7, top: 0.2, right: 0.95, bottom: 0.5),
        centerX: 0.85,
        direction: GuideDirection.right,
        trackingId: 3,
        distanceMeters: 4.0,
      ),
    ];
    pump(engine, objects: far, mode: GuideMode.liveGuide, frames: 1);
    t = t.add(const Duration(milliseconds: 300));
    final close = [
      GuideObjectSnapshot(
        label: 'car',
        confidence: 0.9,
        boundingBox: (left: 0.36, top: 0.2, right: 0.64, bottom: 0.9),
        centerX: 0.5,
        direction: GuideDirection.center,
        trackingId: 3,
        movementState: MovementState.approaching,
        distanceMeters: 0.8,
        boxProximity: 0.8,
      ),
    ];
    final next = engine.evaluateSnapshots(
      snapshots: close,
      mode: GuideMode.liveGuide,
    );
    expect(next.announcements, isNotEmpty);
  });

  test('find my purse → target match 1.0', () {
    final search = TargetSearchService(config);
    expect(search.match('purse', 'purse'), 1.0);
    expect(search.match('handbag', 'purse'), 0.90);
    expect(search.match('backpack', 'purse'), 0.50);
    expect(search.match('chair', 'purse'), 0.00);
  });

  test('target score >= 75 + confirmation → FOUND', () {
    final engine = GuideAlertEngine();
    final objects = [
      GuideObjectSnapshot(
        label: 'purse',
        confidence: 0.86,
        boundingBox: (left: 0.15, top: 0.3, right: 0.35, bottom: 0.6),
        centerX: 0.25,
        direction: GuideDirection.slightLeft,
        trackingId: 9,
        distanceMeters: 2.0,
      ),
    ];
    final spoken = pump(
      engine,
      objects: objects,
      mode: GuideMode.targetSearch,
      target: 'purse',
      frames: 4,
    );
    expect(spoken, isNotEmpty);
    expect(spoken.first.decision, AnnouncementDecision.announceTarget);
    expect(spoken.first.priorityScore, greaterThanOrEqualTo(75));
  });

  test('target score < 75 → continue search', () {
    final engine = GuideAlertEngine();
    final objects = [
      centerObject(label: 'chair', confidence: 0.99, id: 2),
    ];
    final spoken = pump(
      engine,
      objects: objects,
      mode: GuideMode.targetSearch,
      target: 'purse',
      frames: 4,
    );
    expect(spoken, isEmpty);
    expect(spoken.every((a) => a.decision != AnnouncementDecision.announceTarget), isTrue);
  });

  test('target timeout → NOT_FOUND', () {
    var t = DateTime(2026, 1, 1, 12, 0, 0);
    final engine = GuideAlertEngine(
      config: const GuideConfig(targetSearchTimeout: Duration(seconds: 2)),
      clock: () => t,
    );
    engine.startTargetSearch('purse');
    engine.evaluateSnapshots(
      snapshots: [centerObject(label: 'chair', confidence: 0.9)],
      mode: GuideMode.targetSearch,
      findTarget: 'purse',
    );
    t = t.add(const Duration(seconds: 3));
    final result = engine.evaluateSnapshots(
      snapshots: [centerObject(label: 'chair', confidence: 0.9)],
      mode: GuideMode.targetSearch,
      findTarget: 'purse',
    );
    expect(result.targetTimedOut, isTrue);
    expect(result.announcements.first.decision, AnnouncementDecision.notFound);
  });

  test('safety event during target search → safety override', () {
    final engine = GuideAlertEngine();
    engine.startTargetSearch('purse');
    final objects = [
      centerObject(
        label: 'car',
        confidence: 0.85,
        movement: MovementState.approaching,
        meters: 1.0,
        id: 4,
      ),
      GuideObjectSnapshot(
        label: 'purse',
        confidence: 0.9,
        boundingBox: (left: 0.1, top: 0.2, right: 0.2, bottom: 0.4),
        centerX: 0.15,
        direction: GuideDirection.left,
        trackingId: 8,
        distanceMeters: 2,
      ),
    ];
    final spoken = pump(
      engine,
      objects: objects,
      mode: GuideMode.targetSearch,
      target: 'purse',
      frames: 1,
    );
    expect(spoken, isNotEmpty);
    expect(spoken.first.safetyOverride, isTrue);
  });

  test('multiple objects → highest priority first', () {
    final engine = GuideAlertEngine();
    final objects = [
      centerObject(label: 'bottle', confidence: 0.99, id: 1, meters: 3),
      centerObject(label: 'chair', confidence: 0.95, id: 2, meters: 0.8),
      centerObject(label: 'stairs', confidence: 0.84, id: 3, meters: 0.8),
    ];
    final spoken = pump(engine, objects: objects, mode: GuideMode.liveGuide, frames: 1);
    expect(spoken, isNotEmpty);
    expect(spoken.first.label, 'stairs');
  });
}
