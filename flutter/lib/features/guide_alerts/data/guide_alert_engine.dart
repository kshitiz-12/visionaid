import '../../vision/domain/services/object_detector_service.dart';
import '../domain/guide_config.dart';
import '../domain/guide_models.dart';
import 'announcement_cooldown_service.dart';
import 'object_priority_engine.dart';
import 'research_logger.dart';
import 'response_generator.dart';
import 'risk_evaluator.dart';
import 'temporal_confirmation_service.dart';

class GuideAlertEngine {
  GuideAlertEngine({
    GuideConfig? config,
    DateTime Function()? clock,
  })  : config = config ?? const GuideConfig(),
        _now = clock ?? DateTime.now {
    scoring = ObjectPriorityEngine(this.config);
    risk = RiskEvaluator(this.config);
    temporal = TemporalConfirmationService(window: 10);
    cooldown = AnnouncementCooldownService(this.config);
    speech = const ResponseGenerator();
    logger = ResearchLogger();
  }

  final GuideConfig config;
  final DateTime Function() _now;
  late final ObjectPriorityEngine scoring;
  late final RiskEvaluator risk;
  late final TemporalConfirmationService temporal;
  late final AnnouncementCooldownService cooldown;
  late final ResponseGenerator speech;
  late final ResearchLogger logger;

  DateTime? _targetStartedAt;
  String _targetLabel = '';
  bool _toldNotFound = false;
  final Map<String, double> _lastProx = {};
  final Set<String> _saidReached = {};

  void startTargetSearch(String label) {
    _targetLabel = label.trim().toLowerCase();
    _targetStartedAt = _now();
    _toldNotFound = false;
  }

  void keepLooking() {
    _targetStartedAt = _now();
    _toldNotFound = false;
  }

  void cancelTargetSearch() {
    _targetLabel = '';
    _targetStartedAt = null;
    _toldNotFound = false;
  }

  String sceneHint(List<RawDetection> detections) {
    final snaps = detections.map(_toSnapshot).toList();
    if (snaps.isEmpty) {
      return '';
    }
    snaps.sort((a, b) => b.boxProximity.compareTo(a.boxProximity));
    return speech.live(
      snap: snaps.first,
      others: snaps,
      band: PriorityBand.announce,
      risk: 0,
      movement: MovementState.unknown,
      reached: speech.isReached(snaps.first.boxProximity, snaps.first.direction),
    );
  }

  FrameAlertResult evaluateFrame({
    required List<RawDetection> detections,
    required GuideMode mode,
    String findTarget = '',
  }) {
    return evaluateSnapshots(
      snapshots: detections.map(_toSnapshot).toList(),
      mode: mode,
      findTarget: findTarget,
    );
  }

  FrameAlertResult evaluateSnapshots({
    required List<GuideObjectSnapshot> snapshots,
    required GuideMode mode,
    String findTarget = '',
  }) {
    final now = _now();
    if (mode == GuideMode.targetSearch && findTarget.isNotEmpty) {
      if (_targetLabel != findTarget.trim().toLowerCase() || _targetStartedAt == null) {
        startTargetSearch(findTarget);
      }
    } else if (mode != GuideMode.targetSearch) {
      cancelTargetSearch();
    }

    temporal.beginFrame();
    for (final snap in snapshots) {
      temporal.observe(_key(snap), snap.confidence);
    }
    temporal.endFrame();

    final debug = <String>[];
    final scored = <_Ranked>[];

    for (final snap in snapshots) {
      final ranked = _scoreOne(
        snap: snap,
        all: snapshots,
        mode: mode,
        findTarget: findTarget,
        now: now,
      );
      debug.add(ranked.debug);
      if (config.researchLog) {
        logger.record(ranked.debug, object: ranked.announcement?.label ?? '');
      }
      scored.add(ranked);
    }

    scored.sort((a, b) => b.sortKey.compareTo(a.sortKey));

    if (mode == GuideMode.targetSearch &&
        _targetStartedAt != null &&
        now.difference(_targetStartedAt!) >= config.targetSearchTimeout &&
        !_toldNotFound) {
      final found = scored.any((s) => s.announcement?.decision == AnnouncementDecision.announceTarget);
      if (!found) {
        _toldNotFound = true;
        return FrameAlertResult(
          announcements: [
            GuideAnnouncement(
              spoken: speech.targetNotFound(findTarget.isEmpty ? 'object' : findTarget),
              decision: AnnouncementDecision.notFound,
              band: PriorityBand.announce,
              priorityScore: 0,
              trackKey: 'target-timeout',
              label: findTarget,
              speechPriority: SpeechPriority.medium,
              debugLine: 'TARGET timeout',
            ),
          ],
          debugLines: debug,
          targetTimedOut: true,
        );
      }
    }

    final safety = scored.where((s) => s.announcement?.safetyOverride == true).toList();
    if (safety.isNotEmpty) {
      final first = safety.first.announcement!;
      _commit(first, safety.first, now);
      return FrameAlertResult(announcements: [first], debugLines: debug);
    }

    if (mode == GuideMode.targetSearch) {
      final hit = scored.where(
        (s) => s.announcement?.decision == AnnouncementDecision.announceTarget,
      );
      if (hit.isNotEmpty) {
        final first = hit.first.announcement!;
        _commit(first, hit.first, now);
        return FrameAlertResult(announcements: [first], debugLines: debug);
      }
      return FrameAlertResult(announcements: const [], debugLines: debug);
    }

    final eligible = scored.where((s) => s.announcement != null).toList();
    if (eligible.isEmpty) {
      return FrameAlertResult(announcements: const [], debugLines: debug);
    }
    final first = eligible.first.announcement!;
    _commit(first, eligible.first, now);
    return FrameAlertResult(announcements: [first], debugLines: debug);
  }

  void _commit(GuideAnnouncement a, _Ranked ranked, DateTime now) {
    cooldown.markAnnounced(
      key: a.trackKey,
      now: now,
      distanceScore: ranked.distanceScore,
      pathScore: ranked.pathScore,
      riskScore: ranked.riskScore,
      movement: ranked.movement,
      state: a.safetyOverride ? ObjectTrackState.danger : ObjectTrackState.announced,
    );
  }

  _Ranked _scoreOne({
    required GuideObjectSnapshot snap,
    required List<GuideObjectSnapshot> all,
    required GuideMode mode,
    required String findTarget,
    required DateTime now,
  }) {
    final key = _key(snap);
    final conf = snap.confidence.clamp(0.0, 1.0);

    if (conf < config.veryLowConfidence) {
      return _Ranked.suppress(
        snap: snap,
        key: key,
        reason: 'very-low-confidence',
        debug: _debug(snap, 0, PriorityBand.suppress, 'very-low-confidence', 0, 0, 0, 0, 0, 0),
      );
    }

    final box = snap.boundingBox;
    final path = scoring.pathBand(
      boxLeft: box?.left,
      boxRight: box?.right,
      centerX: snap.centerX,
    );
    final pathS = scoring.pathScore(path);
    final riskS = risk.riskFor(snap.label, inPath: pathS >= 0.70);
    final distS = scoring.distanceScoreFromMeters(snap.distanceMeters);
    var movement = snap.movementState;
    if (movement == MovementState.unknown && snap.isMoving) {
      movement = MovementState.moving;
    }
    final moveS = scoring.movementScore(movement);
    final frames = temporal.consecutiveFrames(key);
    final highRisk = riskS >= 0.80;
    final needed = highRisk ? config.safetyConfirmationFrames : config.requiredConfirmationFrames;
    final stable = temporal.confirmed(key, needed);

    final safety = _isCriticalSafety(
      confidence: conf,
      risk: riskS,
      path: pathS,
      distanceScore: distS,
      movement: movement,
      boxProximity: snap.boxProximity,
      stable: stable,
      frames: frames,
    );

    final novelty = _novelty(key, now, pathS, distS, riskS, movement);
    final intentS = scoring.intentScore(
      mode: mode,
      label: snap.label,
      path: path,
      target: findTarget,
    );

    if (safety) {
      final prio = scoring.priorityScore(
        PriorityFactors(
          confidence: conf,
          riskScore: riskS,
          pathScore: pathS,
          distanceScore: distS,
          movementScore: moveS,
          intentScore: intentS,
          noveltyScore: novelty,
        ),
      );
      final spoken = speech.live(
        snap: snap,
        others: all,
        band: PriorityBand.critical,
        risk: riskS,
        movement: movement,
        reached: speech.isReached(snap.boxProximity, snap.direction),
      );
      return _Ranked(
        sortKey: 1000 + prio,
        distanceScore: distS,
        pathScore: pathS,
        riskScore: riskS,
        movement: movement,
        announcement: GuideAnnouncement(
          spoken: spoken,
          decision: AnnouncementDecision.announceSafety,
          band: PriorityBand.critical,
          priorityScore: prio,
          trackKey: key,
          label: snap.label,
          speechPriority: SpeechPriority.critical,
          safetyOverride: true,
          debugLine: _debug(snap, prio, PriorityBand.critical, 'safety-override', conf, riskS, pathS, distS, moveS, intentS, novelty),
        ),
        debug: _debug(snap, prio, PriorityBand.critical, 'safety-override', conf, riskS, pathS, distS, moveS, intentS, novelty),
      );
    }

    if (mode == GuideMode.targetSearch) {
      final match = scoring.targetMatch(snap.label, findTarget);
      final temporalS = temporal.consistency(key, config.targetWindowFrames);
      final tScore = scoring.targetScore(
        TargetFactors(
          targetMatch: match,
          confidence: conf,
          distanceScore: distS,
          directionRelevance: scoring.directionRelevance(snap.direction),
          temporalConsistency: temporalS,
        ),
      );
      final reached = match > 0 &&
          speech.isReached(snap.boxProximity, snap.direction);
      final found = match > 0 &&
          ((tScore >= config.targetFoundScore &&
                  conf >= config.targetMinConfidence &&
                  temporal.confirmed(key, config.safetyConfirmationFrames)) ||
              reached);
      final dbg = _debug(snap, tScore, found ? PriorityBand.highPriority : PriorityBand.suppress, found ? 'target-found' : 'searching', conf, riskS, pathS, distS, moveS, match, temporalS);
      if (found) {
        return _Ranked(
          sortKey: 500 + tScore,
          distanceScore: distS,
          pathScore: pathS,
          riskScore: riskS,
          movement: movement,
          announcement: GuideAnnouncement(
            spoken: speech.targetFound(
              label: findTarget,
              direction: snap.direction,
              distanceMeters: snap.distanceMeters,
              proximity: snap.boxProximity,
              reached: reached,
            ),
            decision: AnnouncementDecision.announceTarget,
            band: PriorityBand.highPriority,
            priorityScore: tScore,
            trackKey: key,
            label: snap.label,
            speechPriority: SpeechPriority.high,
            debugLine: dbg,
          ),
          debug: dbg,
        );
      }
      return _Ranked.suppress(
        snap: snap,
        key: key,
        reason: 'searching',
        debug: dbg,
        distanceScore: distS,
        pathScore: pathS,
        riskScore: riskS,
        movement: movement,
      );
    }

    if (conf < config.minimumConfidence && riskS < 0.80) {
      return _Ranked.suppress(
        snap: snap,
        key: key,
        reason: 'below-min-confidence',
        debug: _debug(snap, 0, PriorityBand.suppress, 'below-min-confidence', conf, riskS, pathS, distS, moveS, intentS, novelty),
        distanceScore: distS,
        pathScore: pathS,
        riskScore: riskS,
        movement: movement,
      );
    }

    if (!stable && riskS < 0.80) {
      return _Ranked.suppress(
        snap: snap,
        key: key,
        reason: 'temporal',
        debug: _debug(snap, 0, PriorityBand.suppress, 'temporal', conf, riskS, pathS, distS, moveS, intentS, novelty),
        distanceScore: distS,
        pathScore: pathS,
        riskScore: riskS,
        movement: movement,
      );
    }

    final prio = scoring.priorityScore(
      PriorityFactors(
        confidence: conf,
        riskScore: riskS,
        pathScore: pathS,
        distanceScore: distS,
        movementScore: moveS,
        intentScore: intentS,
        noveltyScore: novelty,
      ),
    );
    final band = scoring.bandFor(prio);
    if (prio < config.announceThreshold) {
      return _Ranked.suppress(
        snap: snap,
        key: key,
        reason: 'low-relevance',
        debug: _debug(snap, prio, band, 'low-relevance', conf, riskS, pathS, distS, moveS, intentS, novelty),
        distanceScore: distS,
        pathScore: pathS,
        riskScore: riskS,
        movement: movement,
      );
    }

    final changed = cooldown.significantChange(
      key: key,
      distanceScore: distS,
      pathScore: pathS,
      riskScore: riskS,
      movement: movement,
    );
    final reached = speech.isReached(snap.boxProximity, snap.direction);
    final prevProx = _lastProx[key];
    final closer =
        prevProx != null && snap.boxProximity > prevProx + 0.08;
    _lastProx[key] = snap.boxProximity;

    if (cooldown.recentlyAnnounced(key, now) && !changed) {
      if (!(reached && !_saidReached.contains(key)) && !closer) {
        return _Ranked.suppress(
          snap: snap,
          key: key,
          reason: 'cooldown',
          debug: _debug(snap, prio, band, 'cooldown', conf, riskS, pathS, distS, moveS, intentS, novelty),
          distanceScore: distS,
          pathScore: pathS,
          riskScore: riskS,
          movement: movement,
        );
      }
    }

    if (reached) {
      _saidReached.add(key);
    }

    final spoken = speech.live(
      snap: snap,
      others: all,
      band: band,
      risk: riskS,
      movement: movement,
      reached: reached,
      gettingCloser: closer && !reached,
    );
    return _Ranked(
      sortKey: prio,
      distanceScore: distS,
      pathScore: pathS,
      riskScore: riskS,
      movement: movement,
      announcement: GuideAnnouncement(
        spoken: spoken,
        decision: AnnouncementDecision.announce,
        band: band,
        priorityScore: prio,
        trackKey: key,
        label: snap.label,
        speechPriority: band == PriorityBand.critical
            ? SpeechPriority.critical
            : (band == PriorityBand.highPriority ? SpeechPriority.high : SpeechPriority.medium),
        debugLine: _debug(snap, prio, band, 'announce', conf, riskS, pathS, distS, moveS, intentS, novelty),
      ),
      debug: _debug(snap, prio, band, 'announce', conf, riskS, pathS, distS, moveS, intentS, novelty),
    );
  }

  bool _isCriticalSafety({
    required double confidence,
    required double risk,
    required double path,
    required double distanceScore,
    required MovementState movement,
    required double boxProximity,
    required bool stable,
    required int frames,
  }) {
    if (confidence < 0.55) {
      return false;
    }
    if (frames < config.safetyConfirmationFrames) {
      return false;
    }
    final close = distanceScore >= 0.65 || boxProximity >= 0.55;
    final vehicleRush = risk >= 0.85 &&
        path >= 0.70 &&
        (movement == MovementState.approaching || movement == MovementState.crossingPath);
    final stairsClose = risk >= 0.85 && path >= 0.70 && close;
    final obstacleClose = path >= 0.95 && close && risk >= 0.80;
    return vehicleRush || stairsClose || obstacleClose;
  }

  double _novelty(
    String key,
    DateTime now,
    double pathS,
    double distS,
    double riskS,
    MovementState movement,
  ) {
    if (cooldown.stateOf(key) == ObjectTrackState.isNew) {
      return 1.0;
    }
    if (cooldown.significantChange(
      key: key,
      distanceScore: distS,
      pathScore: pathS,
      riskScore: riskS,
      movement: movement,
    )) {
      return 0.80;
    }
    if (cooldown.recentlyAnnounced(key, now)) {
      return 0.10;
    }
    return 0.0;
  }

  GuideObjectSnapshot _toSnapshot(RawDetection d) {
    final fw = d.frameWidth <= 0 ? 0.0 : d.frameWidth;
    final fh = d.frameHeight <= 0 ? 0.0 : d.frameHeight;
    double? cx;
    double? cy;
    ({double left, double top, double right, double bottom})? box;
    if (fw > 0 && d.boxWidth > 0) {
      final left = d.boxLeft / fw;
      final right = (d.boxLeft + d.boxWidth) / fw;
      final top = fh > 0 ? d.boxTop / fh : 0.0;
      final bottom = fh > 0 ? (d.boxTop + d.boxHeight) / fh : 0.0;
      box = (left: left, top: top, right: right, bottom: bottom);
      cx = (left + right) / 2;
      cy = fh > 0 ? (top + bottom) / 2 : null;
    }
    final direction = scoring.directionFromX(cx);
    return GuideObjectSnapshot(
      label: d.label,
      confidence: d.confidence,
      boundingBox: box,
      centerX: cx,
      centerY: cy,
      distanceMeters: d.distanceMeters,
      direction: direction,
      movementState: d.isMoving ? MovementState.moving : MovementState.unknown,
      trackingId: d.trackingId,
      timestamp: d.timestamp,
      isMoving: d.isMoving,
      boxProximity: d.distance,
    );
  }

  String _key(GuideObjectSnapshot snap) {
    if (snap.trackingId != null) {
      return '${snap.label}-${snap.trackingId}';
    }
    final x = snap.centerX?.toStringAsFixed(1) ?? 'u';
    return '${snap.label}-$x';
  }

  String _debug(
    GuideObjectSnapshot snap,
    double score,
    PriorityBand band,
    String reason,
    double c,
    double r,
    double p,
    double d,
    double m,
    double i, [
    double n = 0,
  ]) {
    return '${snap.label} conf=${c.toStringAsFixed(2)} risk=${r.toStringAsFixed(2)} '
        'path=${p.toStringAsFixed(2)} dist=${d.toStringAsFixed(2)} move=${m.toStringAsFixed(2)} '
        'intent=${i.toStringAsFixed(2)} novelty=${n.toStringAsFixed(2)} '
        'score=${score.toStringAsFixed(1)} $band $reason';
  }
}

class _Ranked {
  _Ranked({
    required this.sortKey,
    required this.distanceScore,
    required this.pathScore,
    required this.riskScore,
    required this.movement,
    required this.debug,
    this.announcement,
  });

  factory _Ranked.suppress({
    required GuideObjectSnapshot snap,
    required String key,
    required String reason,
    required String debug,
    double distanceScore = 0,
    double pathScore = 0,
    double riskScore = 0,
    MovementState movement = MovementState.unknown,
  }) {
    return _Ranked(
      sortKey: -1,
      distanceScore: distanceScore,
      pathScore: pathScore,
      riskScore: riskScore,
      movement: movement,
      debug: debug,
    );
  }

  final double sortKey;
  final double distanceScore;
  final double pathScore;
  final double riskScore;
  final MovementState movement;
  final String debug;
  final GuideAnnouncement? announcement;
}
