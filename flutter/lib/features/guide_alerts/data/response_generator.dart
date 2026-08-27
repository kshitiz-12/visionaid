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

  String metresOrBoxPhrase(double? metres, double proximity) {
    if (metres == null) {
      return distancePhrase(proximity);
    }
    if (metres < 0.9) {
      return hindi ? 'पास' : 'close';
    }
    if (metres < 1.7) {
      return hindi ? 'एक मीटर' : 'one metre';
    }
    if (metres < 2.4) {
      return hindi ? 'दो मीटर' : 'two metres';
    }
    return '';
  }

  String distancePhrase(double proximity) {
    if (proximity >= 0.42) {
      return hindi ? 'पास' : 'close';
    }
    if (proximity >= 0.22) {
      return hindi ? 'एक मीटर' : 'one metre';
    }
    if (proximity >= 0.10) {
      return hindi ? 'दो मीटर' : 'two metres';
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
    final dist = metresOrBoxPhrase(snap.distanceMeters, snap.boxProximity);
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
  }) {
    if (reached) {
      return hindi
          ? 'रुकिए. $label मिल गया.'
          : 'Stop. You have reached the $label.';
    }
    return _line(_cap(label), directionPhrase(direction), metresOrBoxPhrase(distanceMeters, proximity));
  }

  String targetNotFound(String label) {
    return hindi
        ? '$label नहीं मिला. थोड़ा घुमाइए.'
        : "I still don't have the $label. Sweep a little left and right.";
  }

  String _line(String name, String dir, String dist) {
    if (dist.isEmpty) {
      return '$name, $dir.';
    }
    return '$name, $dir, $dist.';
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
