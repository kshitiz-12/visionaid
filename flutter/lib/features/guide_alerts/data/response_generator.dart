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
    final spoken = _spokenName(snap);
    final direction = snap.direction;
    final proximity = snap.boxProximity;
    final dir = directionPhrase(direction);
    final dist = metresOrBoxPhrase(snap.distanceMeters, proximity);
    final where = SpatialRelations.phrase(snap, others);
    final extra = extras(others, skipLabel: snap.label);

    if (reached && !_isVehicle(snap.label) && snap.label != 'stairs') {
      return 'Stop. ${_cap(spoken)} $dir, $dist.$extra';
    }

    if (_unnamed(snap.label)) {
      if (band == PriorityBand.critical || risk >= 0.80) {
        return 'Stop. ${_cap(spoken)} $dir, $dist.$extra';
      }
      return '${_cap(spoken)} $dir, $dist.$extra';
    }
    if (snap.label == 'stairs') {
      return 'Stairs $dir, $dist. Slow down.$extra';
    }
    if (band == PriorityBand.critical || risk >= 0.85) {
      if (_isVehicle(snap.label)) {
        final motion = movement == MovementState.approaching
            ? 'A vehicle is coming from $dir, $dist.'
            : 'There is a vehicle $dir, $dist.';
        return 'Careful. $motion$extra';
      }
      return 'Stop. ${_cap(spoken)} $dir, $dist.$extra';
    }
    if (_isVehicle(snap.label)) {
      if (movement == MovementState.approaching) {
        return 'Careful. A vehicle is coming from $dir, $dist.$extra';
      }
      return 'There is a vehicle $dir, $dist.$extra';
    }

    if (gettingCloser) {
      return 'Keep coming. The $spoken is closer, $dir, $dist.$extra';
    }

    if (where != null && where.isNotEmpty) {
      return 'The $spoken is $where, $dir, $dist.$extra';
    }

    return 'The $spoken is $dir, $dist.$extra';
  }

  String extras(List<GuideObjectSnapshot> snaps, {required String skipLabel}) {
    final lines = <String>[];
    for (final snap in snaps) {
      final label = snap.label.trim().toLowerCase();
      if (label.isEmpty ||
          label == skipLabel.trim().toLowerCase() ||
          _unnamed(label)) {
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

  String _spokenName(GuideObjectSnapshot snap) {
    final l = snap.label.trim().toLowerCase();
    if (l.isNotEmpty &&
        l != 'object' &&
        l != 'unknown' &&
        l != 'obstacle' &&
        l != 'wall' &&
        l != 'something') {
      return l;
    }
    final box = snap.boundingBox;
    if (box == null) {
      return 'nearby thing';
    }
    final h = (box.bottom - box.top).clamp(0.0, 1.0);
    final w = (box.right - box.left).clamp(0.0, 1.0);
    if (h >= 0.55) {
      return 'tall thing';
    }
    if (w >= 0.45) {
      return 'wide thing';
    }
    if (h <= 0.18) {
      return 'low thing';
    }
    return 'nearby thing';
  }

  bool _unnamed(String label) {
    final l = label.trim().toLowerCase();
    return l.isEmpty ||
        l == 'wall' ||
        l == 'obstacle' ||
        l == 'object' ||
        l == 'unknown' ||
        l == 'something';
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
