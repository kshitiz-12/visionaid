import '../../../services/memory_tracker.dart';
import '../domain/guide_config.dart';
import '../domain/guide_models.dart';

class ObjectPriorityEngine {
  const ObjectPriorityEngine(this.config);

  final GuideConfig config;

  /// Exact initial formula. Factors are 0–1. Result is 0–100.
  double priorityScore(PriorityFactors f) {
    final raw = config.confidenceWeight * f.confidence +
        config.riskWeight * f.riskScore +
        config.pathWeight * f.pathScore +
        config.distanceWeight * f.distanceScore +
        config.movementWeight * f.movementScore +
        config.intentWeight * f.intentScore +
        config.noveltyWeight * f.noveltyScore;
    return raw.clamp(0.0, 100.0);
  }

  double targetScore(TargetFactors f) {
    final raw = config.targetMatchWeight * f.targetMatch +
        config.targetConfidenceWeight * f.confidence +
        config.targetDistanceWeight * f.distanceScore +
        config.targetDirectionWeight * f.directionRelevance +
        config.targetTemporalWeight * f.temporalConsistency;
    return raw.clamp(0.0, 100.0);
  }

  PriorityBand bandFor(double score) {
    if (score < config.lowPriorityThreshold) {
      return PriorityBand.suppress;
    }
    if (score < config.announceThreshold) {
      return PriorityBand.lowPriority;
    }
    if (score < config.highPriorityThreshold) {
      return PriorityBand.announce;
    }
    if (score < config.criticalThreshold) {
      return PriorityBand.highPriority;
    }
    return PriorityBand.critical;
  }

  double distanceScoreFromMeters(double? meters) {
    if (meters == null) {
      return config.neutralDistanceScore;
    }
    final m = meters;
    if (m >= 5.0) {
      return 0.10;
    }
    if (m <= 0.5) {
      return 1.00;
    }
    const points = <({double m, double s})>[
      (m: 0.5, s: 1.00),
      (m: 1.0, s: 0.90),
      (m: 2.0, s: 0.65),
      (m: 3.0, s: 0.40),
      (m: 4.0, s: 0.25),
      (m: 5.0, s: 0.10),
    ];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (m >= a.m && m <= b.m) {
        final t = (m - a.m) / (b.m - a.m);
        return (a.s + (b.s - a.s) * t).clamp(0.0, 1.0);
      }
    }
    return config.neutralDistanceScore;
  }

  double movementScore(MovementState state) {
    return switch (state) {
      MovementState.staticState => 0.10,
      MovementState.movingAway => 0.30,
      MovementState.moving => 0.50,
      MovementState.approaching => 0.85,
      MovementState.crossingPath => 1.00,
      MovementState.unknown => 0.20,
    };
  }

  PathBand pathBand({
    required double? boxLeft,
    required double? boxRight,
    required double? centerX,
  }) {
    if (boxLeft == null || boxRight == null || boxRight <= boxLeft) {
      if (centerX == null) {
        return PathBand.unknown;
      }
      if (centerX >= config.corridorLeft && centerX <= config.corridorRight) {
        return PathBand.directlyInPath;
      }
      if (centerX >= 0.20 && centerX <= 0.80) {
        return PathBand.side;
      }
      return PathBand.outsidePath;
    }

    final overlapLeft = boxLeft > config.corridorLeft ? boxLeft : config.corridorLeft;
    final overlapRight = boxRight < config.corridorRight ? boxRight : config.corridorRight;
    final overlap = overlapRight > overlapLeft ? overlapRight - overlapLeft : 0.0;
    final width = boxRight - boxLeft;
    final fraction = width <= 0 ? 0.0 : overlap / width;

    if (fraction >= 0.45) {
      return PathBand.directlyInPath;
    }
    if (fraction >= 0.12) {
      return PathBand.nearPath;
    }
    final cx = centerX ?? ((boxLeft + boxRight) / 2);
    if (cx >= 0.18 && cx <= 0.82) {
      return PathBand.side;
    }
    return PathBand.outsidePath;
  }

  double pathScore(PathBand band) {
    return switch (band) {
      PathBand.directlyInPath => 1.00,
      PathBand.nearPath => 0.70,
      PathBand.side => 0.30,
      PathBand.outsidePath => 0.10,
      PathBand.unknown => 0.20,
    };
  }

  GuideDirection directionFromX(double? centerX) {
    if (centerX == null) {
      return GuideDirection.unknown;
    }
    if (centerX < 0.20) {
      return GuideDirection.left;
    }
    if (centerX < 0.40) {
      return GuideDirection.slightLeft;
    }
    if (centerX < 0.60) {
      return GuideDirection.center;
    }
    if (centerX < 0.80) {
      return GuideDirection.slightRight;
    }
    return GuideDirection.right;
  }

  double directionRelevance(GuideDirection d) {
    return switch (d) {
      GuideDirection.center => 1.00,
      GuideDirection.slightLeft => 0.90,
      GuideDirection.slightRight => 0.90,
      GuideDirection.left => 0.75,
      GuideDirection.right => 0.75,
      GuideDirection.unknown => 0.30,
    };
  }

  double intentScore({
    required GuideMode mode,
    required String label,
    required PathBand path,
    String target = '',
  }) {
    if (mode == GuideMode.liveGuide) {
      return 0.0;
    }
    if (mode == GuideMode.targetSearch) {
      return 0;
    }
    final inFront = path == PathBand.directlyInPath || path == PathBand.nearPath;
    if (target == 'person' || target == 'people') {
      return (label == 'person' || label == 'people') ? 1.0 : 0.0;
    }
    if (inFront) {
      return 1.0;
    }
    if (path == PathBand.side) {
      return 0.40;
    }
    return 0.20;
  }

  double targetMatch(String detected, String requested) {
    final d = detected.trim().toLowerCase();
    final r = requested.trim().toLowerCase();
    if (r.isEmpty) {
      return 0;
    }
    // Weak cross-bag matches (not full synonyms).
    if ((r == 'purse' || r == 'handbag') && d == 'backpack') {
      return 0.50;
    }
    if (r == 'backpack' && (d == 'purse' || d == 'handbag')) {
      return 0.50;
    }
    // Semantic synonym / stem match (system-wide MemoryTracker taxonomy).
    final semantic = MemoryTracker.semanticMatch(d, r);
    if (semantic > 0) {
      return semantic;
    }
    if (d == r) {
      return 1.0;
    }
    final aliases = config.targetAliases[r] ?? const <String>[];
    if (aliases.contains(d)) {
      return d == r ? 1.0 : 0.90;
    }
    for (final entry in config.targetAliases.entries) {
      if (entry.key == r && entry.value.contains(d)) {
        return d == r ? 1.0 : 0.90;
      }
    }
    return 0.0;
  }
}
