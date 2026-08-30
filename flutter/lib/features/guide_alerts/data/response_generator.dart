import '../domain/guide_models.dart';

class ResponseGenerator {
  const ResponseGenerator({this.hindi = false});

  final bool hindi;

  /// Left, slight left, ahead, slight right, right.
  String directionPhrase(GuideDirection d) {
    return switch (d) {
      GuideDirection.left => hindi ? 'बाएँ' : 'left',
      GuideDirection.slightLeft => hindi ? 'थोड़ा बाएँ' : 'slight left',
      GuideDirection.center => hindi ? 'सामने' : 'ahead',
      GuideDirection.slightRight => hindi ? 'थोड़ा दाएँ' : 'slight right',
      GuideDirection.right => hindi ? 'दाएँ' : 'right',
      GuideDirection.unknown => hindi ? 'सामने' : 'ahead',
    };
  }

  String metresOrBoxPhrase(
    double? metres,
    double proximity, {
    double? boxArea,
  }) {
    if (boxArea != null && boxArea > 0.40) {
      return hindi ? 'बहुत पास / आपकी गोद में' : 'very close / in your lap';
    }
    if (metres == null) {
      return distancePhrase(proximity);
    }
    if (metres < 0.55 || proximity >= 0.55) {
      return hindi ? 'बहुत पास' : 'very close';
    }
    if (metres < 0.9) {
      return hindi
          ? 'लगभग ${(metres * 100).round()} सेमी'
          : 'about ${(metres * 100).round()} centimeters';
    }
    if (metres < 2.8) {
      final rounded = (metres * 10).round() / 10.0;
      final text = rounded == rounded.roundToDouble()
          ? rounded.toStringAsFixed(0)
          : rounded.toStringAsFixed(1);
      final unit = (rounded == 1.0)
          ? (hindi ? 'मीटर' : 'meter')
          : (hindi ? 'मीटर' : 'meters');
      return hindi ? 'लगभग $text $unit' : 'about $text $unit';
    }
    return hindi ? 'दूर' : 'farther';
  }

  String distancePhrase(double proximity) {
    if (proximity >= 0.55) {
      return hindi ? 'बहुत पास' : 'very close';
    }
    if (proximity >= 0.35) {
      return hindi ? 'पास' : 'close';
    }
    if (proximity >= 0.18) {
      return hindi ? 'थोड़ी दूर' : 'a bit farther';
    }
    return '';
  }

  bool isReached(double proximity, GuideDirection direction) {
    final ahead = direction == GuideDirection.center ||
        direction == GuideDirection.slightLeft ||
        direction == GuideDirection.slightRight ||
        direction == GuideDirection.unknown;
    return proximity >= 0.45 && ahead;
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
    final dir = directionPhrase(snap.direction);
    final dist = metresOrBoxPhrase(
      snap.distanceMeters,
      snap.boxProximity,
      boxArea: boxAreaOf(snap),
    );
    final name = _cap(spoken);
    final sayStop = reached ||
        _isVehicle(snap.label) && band == PriorityBand.critical ||
        _isGroundHazard(snap.label) && band == PriorityBand.critical;

    if (sayStop) {
      if (_isVehicle(snap.label)) {
        return hindi ? 'रुकिए. गाड़ी $dir.' : 'Stop. Vehicle $dir.';
      }
      if (_isGroundHazard(snap.label)) {
        return hindi
            ? 'रुकिए. ${_hiNoun(snap.label)} $dir.'
            : 'Stop. ${_enNoun(snap.label)} $dir.';
      }
      if (dist.isEmpty) {
        return hindi ? 'रुकिए. $name $dir.' : 'Stop. $name $dir.';
      }
      return hindi ? 'रुकिए. $name $dir, $dist.' : 'Stop. $name $dir, $dist.';
    }

    if (_isGroundHazard(snap.label)) {
      return _line(
        hindi ? _hiNoun(snap.label) : _cap(_enNoun(snap.label)),
        dir,
        dist,
      );
    }
    if (_isVehicle(snap.label)) {
      return _line(hindi ? 'गाड़ी' : 'Vehicle', dir, dist);
    }

    return _line(name, dir, dist);
  }

  String extras(List<GuideObjectSnapshot> snaps, {required String skipLabel}) {
    return '';
  }

  String targetFound({
    required String label,
    required GuideDirection direction,
    double? distanceMeters,
    double proximity = 0.2,
    bool reached = false,
    double? boxArea,
  }) {
    if (reached) {
      return hindi
          ? 'रुकिए. $label मिल गया.'
          : 'Stop. You have reached the $label.';
    }
    return _line(
      _cap(label),
      directionPhrase(direction),
      metresOrBoxPhrase(distanceMeters, proximity, boxArea: boxArea),
    );
  }

  String targetNotFound(String label) {
    return hindi
        ? '$label नहीं मिला. थोड़ा घुमाइए.'
        : "I still don't have the $label. Sweep a little left and right.";
  }

  /// Speaks a rolling inventory of what the camera currently sees.
  String sceneInventory(List<GuideObjectSnapshot> snaps) {
    if (snaps.isEmpty) {
      return '';
    }
    final parts = <String>[];
    final seen = <String>{};
    for (final snap in snaps) {
      final key = snap.label.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      final name = _cap(_spokenName(snap));
      final dir = directionPhrase(snap.direction);
      final dist = metresOrBoxPhrase(
      snap.distanceMeters,
      snap.boxProximity,
      boxArea: boxAreaOf(snap),
    );
      if (dist.isEmpty) {
        parts.add('$name $dir');
      } else {
        parts.add('$name $dir, $dist');
      }
      if (parts.length >= 5) {
        break;
      }
    }
    if (parts.isEmpty) {
      return '';
    }
    if (hindi) {
      return 'दिख रहा है: ${parts.join('. ')}.';
    }
    return 'I see ${parts.join('. ')}.';
  }

  String _line(String name, String dir, String dist) {
    if (dist.isEmpty) {
      return '$name, $dir.';
    }
    return '$name, $dir, $dist.';
  }

  /// Normalized frame coverage of a detection box (0..1).
  static double? boxAreaOf(GuideObjectSnapshot snap) {
    final box = snap.boundingBox;
    if (box == null) {
      return null;
    }
    final w = (box.right - box.left).clamp(0.0, 1.0);
    final h = (box.bottom - box.top).clamp(0.0, 1.0);
    return (w * h).clamp(0.0, 1.0);
  }

  String _spokenName(GuideObjectSnapshot snap) {
    final l = snap.label.trim().toLowerCase();
    if (l.isNotEmpty &&
        l != 'object' &&
        l != 'unknown' &&
        l != 'something') {
      if (hindi) {
        return _hiNoun(l);
      }
      return _enNoun(l);
    }
    final box = snap.boundingBox;
    if (box == null) {
      return hindi ? 'चीज़' : 'something';
    }
    final h = (box.bottom - box.top).clamp(0.0, 1.0);
    final w = (box.right - box.left).clamp(0.0, 1.0);
    if (h >= 0.55) {
      return hindi ? 'ऊँची चीज़' : 'tall thing';
    }
    if (w >= 0.45) {
      return hindi ? 'चौड़ी चीज़' : 'wide thing';
    }
    if (h <= 0.18) {
      return hindi ? 'निचली चीज़' : 'low thing';
    }
    return hindi ? 'चीज़' : 'something';
  }

  String _enNoun(String l) {
    return switch (l) {
      'stairs' || 'ladder' => 'stairs',
      'pothole' => 'pothole',
      'open_drain' => 'open drain',
      'curb' => 'curb',
      'wet_floor_sign' => 'wet floor sign',
      'wall' => 'wall',
      'obstacle' => 'obstacle',
      'door' => 'door',
      'inr_10' => '10 rupee note',
      'inr_20' => '20 rupee note',
      'inr_50' => '50 rupee note',
      'inr_100' => '100 rupee note',
      'inr_200' => '200 rupee note',
      'inr_500' => '500 rupee note',
      'blister_pack' => 'pill strip',
      'syrup_bottle' => 'syrup bottle',
      'dropper_bottle' => 'dropper bottle',
      'ointment_tube' => 'ointment tube',
      _ => l,
    };
  }

  String _hiNoun(String l) {
    return switch (l) {
      'person' || 'people' => 'व्यक्ति',
      'chair' => 'कुर्सी',
      'table' => 'मेज़',
      'door' => 'दरवाज़ा',
      'bottle' => 'बोतल',
      'stairs' || 'ladder' => 'सीढ़ियाँ',
      'pothole' => 'गड्ढा',
      'open_drain' => 'खुला नाला',
      'curb' => 'फ़ुटपाथ किनारा',
      'wet_floor_sign' => 'गीला फ़र्श',
      'wall' => 'दीवार',
      'obstacle' => 'रुकावट',
      'car' || 'vehicle' || 'truck' || 'bus' => 'गाड़ी',
      'inr_10' => 'दस रुपये का नोट',
      'inr_20' => 'बीस रुपये का नोट',
      'inr_50' => 'पचास रुपये का नोट',
      'inr_100' => 'सौ रुपये का नोट',
      'inr_200' => 'दो सौ रुपये का नोट',
      'inr_500' => 'पाँच सौ रुपये का नोट',
      'blister_pack' => 'दवाई की पट्टी',
      'syrup_bottle' => 'सिरप की बोतल',
      'dropper_bottle' => 'ड्रॉपर बोतल',
      'ointment_tube' => 'मरहम की ट्यूब',
      _ => l,
    };
  }

  bool _isGroundHazard(String label) {
    return label == 'stairs' ||
        label == 'ladder' ||
        label == 'pothole' ||
        label == 'open_drain' ||
        label == 'curb' ||
        label == 'wet_floor_sign';
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
      return hindi ? 'चीज़' : 'Something';
    }
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}
