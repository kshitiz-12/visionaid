import '../domain/guide_models.dart';
import 'spatial_relations.dart';

class ResponseGenerator {
  const ResponseGenerator();

  String directionPhrase(GuideDirection d) {
    return switch (d) {
      GuideDirection.left => 'on your left',
      GuideDirection.slightLeft => 'a little to your left',
      GuideDirection.center => 'straight ahead',
      GuideDirection.slightRight => 'a little to your right',
      GuideDirection.right => 'on your right',
      GuideDirection.unknown => 'ahead',
    };
  }

  String metresOrBoxPhrase(double? metres, double proximity) {
    if (metres == null) {
      return distancePhrase(proximity);
    }
    if (metres < 0.8) {
      return 'right in front of you';
    }
    if (metres < 1.6) {
      return 'about one metre ahead';
    }
    if (metres < 2.6) {
      return 'about two metres ahead';
    }
    return 'a bit further ahead';
  }

  /// Box size is not a tape measure. These are walking-scale guesses.
  String distancePhrase(double proximity) {
    if (proximity >= 0.42) {
      return 'right in front of you';
    }
    if (proximity >= 0.22) {
      return 'about a meter away';
    }
    if (proximity >= 0.10) {
      return 'about two meters away';
    }
    return 'a bit further ahead';
  }

  bool isReached(double proximity, GuideDirection direction) {
    final ahead = direction == GuideDirection.center ||
        direction == GuideDirection.slightLeft ||
        direction == GuideDirection.slightRight ||
        direction == GuideDirection.unknown;
    return proximity >= 0.45 && ahead;
  }

  String article(String label) {
    final l = label.toLowerCase();
    if (l.isEmpty) {
      return 'a';
    }
    const vowels = 'aeiou';
    if (vowels.contains(l[0])) {
      return 'an';
    }
    return 'a';
  }

  String live({
    required GuideObjectSnapshot snap,
    required List<GuideObjectSnapshot> others,
    required PriorityBand band,
    required double risk,
    required MovementState movement,
    bool reached = false,
    bool gettingCloser = false,
  }) {
    final label = snap.label;
    final direction = snap.direction;
    final proximity = snap.boxProximity;
    final dir = directionPhrase(direction);
    final dist = metresOrBoxPhrase(snap.distanceMeters, proximity);
    final where = SpatialRelations.phrase(snap, others);
    final extra = extras(others, skipLabel: label);

    if (reached && !_isVehicle(label) && label != 'stairs') {
      if (label == 'wall' || label == 'obstacle') {
        return 'Stop. Obstacle $dir, $dist.$extra';
      }
      return 'Stop. ${_cap(label)} $dir, $dist.$extra';
    }

    if (label == 'wall' || label == 'obstacle') {
      if (band == PriorityBand.critical || risk >= 0.80) {
        return 'Stop. Obstacle $dir, $dist.$extra';
      }
      return 'Obstacle $dir, $dist.$extra';
    }
    if (label == 'stairs') {
      return 'Stairs $dir, $dist. Slow down.$extra';
    }
    if (band == PriorityBand.critical || risk >= 0.85) {
      if (_isVehicle(label)) {
        final motion = movement == MovementState.approaching
            ? 'A vehicle is coming from $dir, $dist.'
            : 'There is a vehicle $dir, $dist.';
        return 'Careful. $motion$extra';
      }
      return 'Stop. ${_cap(label)} $dir, $dist.$extra';
    }
    if (_isVehicle(label)) {
      if (movement == MovementState.approaching) {
        return 'Careful. A vehicle is coming from $dir, $dist.$extra';
      }
      return 'There is a vehicle $dir, $dist.$extra';
    }

    if (gettingCloser) {
      return 'Keep coming. The $label is closer, $dir, $dist.$extra';
    }

    if (where != null && where.isNotEmpty) {
      return 'The $label is $where, $dir, $dist.$extra';
    }

    return 'The $label is $dir, $dist.$extra';
  }

  String extras(List<GuideObjectSnapshot> snaps, {required String skipLabel}) {
    final lines = <String>[];
    for (final snap in snaps) {
      final label = snap.label.trim().toLowerCase();
      if (label.isEmpty ||
          label == skipLabel.trim().toLowerCase() ||
          label == 'obstacle' ||
          label == 'wall' ||
          label == 'object') {
        continue;
      }
      if (snap.confidence < 0.32) {
        continue;
      }
      lines.add(
        '${_cap(label)} ${directionPhrase(snap.direction)}, ${metresOrBoxPhrase(snap.distanceMeters, snap.boxProximity)}',
      );
      if (lines.length >= 2) {
        break;
      }
    }
    if (lines.isEmpty) {
      return '';
    }
    return ' ${lines.join('. ')}.';
  }

  String targetFound({
    required String label,
    required GuideDirection direction,
    double? distanceMeters,
    double proximity = 0.2,
    bool reached = false,
  }) {
    if (reached) {
      return 'Stop. You have reached the $label.';
    }
    final dir = directionPhrase(direction);
    final dist = distanceMeters != null && distanceMeters.isFinite
        ? (distanceMeters >= 1
            ? 'about ${distanceMeters.round()} meters away'
            : 'very close')
        : distancePhrase(proximity);
    return 'The $label is $dir, $dist.';
  }

  String targetNotFound(String label) {
    return "I still don't have the $label. Sweep a little left and right.";
  }

  bool _isVehicle(String label) {
    return label == 'car' ||
        label == 'vehicle' ||
        label == 'truck' ||
        label == 'bus' ||
        label == 'motorcycle';
  }

  String _cap(String label) {
    if (label.isEmpty) {
      return 'It';
    }
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}
