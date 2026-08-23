import '../domain/guide_config.dart';
import '../domain/guide_models.dart';

class AnnouncementRecord {
  AnnouncementRecord({
    required this.time,
    required this.distanceScore,
    required this.pathScore,
    required this.riskScore,
    required this.movement,
    required this.state,
  });

  DateTime time;
  double distanceScore;
  double pathScore;
  double riskScore;
  MovementState movement;
  ObjectTrackState state;
}

class AnnouncementCooldownService {
  AnnouncementCooldownService(this.config);

  final GuideConfig config;
  final Map<String, AnnouncementRecord> _last = {};

  ObjectTrackState stateOf(String key) =>
      _last[key]?.state ?? ObjectTrackState.isNew;

  bool recentlyAnnounced(String key, DateTime now) {
    final rec = _last[key];
    if (rec == null) {
      return false;
    }
    return now.difference(rec.time) < config.announcementCooldown;
  }

  bool significantChange({
    required String key,
    required double distanceScore,
    required double pathScore,
    required double riskScore,
    required MovementState movement,
  }) {
    final rec = _last[key];
    if (rec == null) {
      return true;
    }
    if (distanceScore - rec.distanceScore >= 0.25) {
      return true;
    }
    if (pathScore - rec.pathScore >= 0.35) {
      return true;
    }
    if (riskScore - rec.riskScore >= 0.20) {
      return true;
    }
    if (rec.movement != MovementState.approaching &&
        rec.movement != MovementState.crossingPath &&
        (movement == MovementState.approaching ||
            movement == MovementState.crossingPath)) {
      return true;
    }
    if (rec.pathScore < 0.70 && pathScore >= 0.70) {
      return true;
    }
    return false;
  }

  void markAnnounced({
    required String key,
    required DateTime now,
    required double distanceScore,
    required double pathScore,
    required double riskScore,
    required MovementState movement,
    required ObjectTrackState state,
  }) {
    _last[key] = AnnouncementRecord(
      time: now,
      distanceScore: distanceScore,
      pathScore: pathScore,
      riskScore: riskScore,
      movement: movement,
      state: state,
    );
  }
}
