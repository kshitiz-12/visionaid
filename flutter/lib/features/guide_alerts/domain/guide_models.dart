enum GuideDirection { left, slightLeft, center, slightRight, right, unknown }

enum PathBand { directlyInPath, nearPath, side, outsidePath, unknown }

enum MovementState {
  staticState,
  movingAway,
  moving,
  approaching,
  crossingPath,
  unknown,
}

enum ObjectTrackState { isNew, tracked, announced, changed, danger, lost }

enum PriorityBand { suppress, lowPriority, announce, highPriority, critical }

enum AnnouncementDecision {
  announce,
  announceTarget,
  announceSafety,
  suppress,
  continueSearch,
  notFound,
}

enum GuideMode { liveGuide, targetSearch }

enum SpeechPriority { low, medium, high, critical }

class PriorityFactors {
  const PriorityFactors({
    required this.confidence,
    required this.riskScore,
    required this.pathScore,
    required this.distanceScore,
    required this.movementScore,
    required this.intentScore,
    required this.noveltyScore,
  });

  final double confidence;
  final double riskScore;
  final double pathScore;
  final double distanceScore;
  final double movementScore;
  final double intentScore;
  final double noveltyScore;
}

class TargetFactors {
  const TargetFactors({
    required this.targetMatch,
    required this.confidence,
    required this.distanceScore,
    required this.directionRelevance,
    required this.temporalConsistency,
  });

  final double targetMatch;
  final double confidence;
  final double distanceScore;
  final double directionRelevance;
  final double temporalConsistency;
}

class GuideObjectSnapshot {
  const GuideObjectSnapshot({
    required this.label,
    required this.confidence,
    this.boundingBox,
    this.centerX,
    this.centerY,
    this.distanceMeters,
    this.direction = GuideDirection.unknown,
    this.movementState = MovementState.unknown,
    this.trackingId,
    this.timestamp,
    this.isMoving = false,
    this.boxProximity = 0,
  });

  final String label;
  final double confidence;
  final ({double left, double top, double right, double bottom})? boundingBox;
  final double? centerX;
  final double? centerY;
  final double? distanceMeters;
  final GuideDirection direction;
  final MovementState movementState;
  final int? trackingId;
  final DateTime? timestamp;
  final bool isMoving;
  final double boxProximity;
}

class GuideAnnouncement {
  const GuideAnnouncement({
    required this.spoken,
    required this.decision,
    required this.band,
    required this.priorityScore,
    required this.trackKey,
    required this.label,
    required this.speechPriority,
    this.safetyOverride = false,
    this.debugLine = '',
    this.suppressionReason = '',
  });

  final String spoken;
  final AnnouncementDecision decision;
  final PriorityBand band;
  final double priorityScore;
  final String trackKey;
  final String label;
  final SpeechPriority speechPriority;
  final bool safetyOverride;
  final String debugLine;
  final String suppressionReason;
}

class FrameAlertResult {
  const FrameAlertResult({
    required this.announcements,
    this.debugLines = const [],
    this.targetTimedOut = false,
  });

  final List<GuideAnnouncement> announcements;
  final List<String> debugLines;
  final bool targetTimedOut;
}
