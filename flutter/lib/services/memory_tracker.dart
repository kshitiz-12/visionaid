import '../features/vision/data/services/scene_vocab.dart';
import 'spatial_db.dart';

/// Thrown by the silent object-memory logger / recall helper.
class MemoryTrackerException implements Exception {
  const MemoryTrackerException(this.message, {this.code = 'MEMORY_TRACKER'});

  final String message;
  final String code;

  @override
  String toString() => 'MemoryTrackerException($code): $message';
}

class MemoryTrackerConfigException extends MemoryTrackerException {
  const MemoryTrackerConfigException(super.message)
      : super(code: 'MEMORY_TRACKER_CONFIG');
}

class MemoryTrackerNotFoundException extends MemoryTrackerException {
  const MemoryTrackerNotFoundException(super.message)
      : super(code: 'MEMORY_TRACKER_NOT_FOUND');
}

class MemoryTrackerWriteException extends MemoryTrackerException {
  const MemoryTrackerWriteException(super.message)
      : super(code: 'MEMORY_TRACKER_WRITE');
}

/// One YOLO (or fused) detection offered to the silent logger.
class TrackedDetection {
  const TrackedDetection({
    required this.label,
    required this.confidence,
    this.relativeVectorX,
    this.relativeVectorY,
    this.depthZ,
    this.boxArea,
  });

  final String label;
  final double confidence;
  final double? relativeVectorX;
  final double? relativeVectorY;
  final double? depthZ;

  /// Normalized bounding-box area (0..1). ≥ 0.80 = close-up fill (e.g. feet).
  final double? boxArea;
}

/// Spoken recall result for conversational memory.
class MemoryRecallResult {
  const MemoryRecallResult({
    required this.spoken,
    required this.record,
    required this.node,
  });

  final String spoken;
  final ObjectMemoryRecord record;
  final SpatialNode node;
}

/// Sliding window entry for multi-frame persistence.
class _FrameHit {
  _FrameHit({
    required this.label,
    required this.confidence,
    this.relativeVectorX,
    this.relativeVectorY,
    this.depthZ,
    this.boxArea,
  });

  final String label;
  final double confidence;
  final double? relativeVectorX;
  final double? relativeVectorY;
  final double? depthZ;
  final double? boxArea;
}

/// Background silent logger for objects + conversational recall.
///
/// Requires **3 detections in the last 5 frames** before SQLite insert.
/// Logging never speaks. [locateLastSeen] formats speech for the caller.
class MemoryTracker {
  MemoryTracker({
    required SpatialDb spatialDb,
    Set<String>? highValueLabels,
    double minConfidence = 0.45,
    Duration minLogInterval = const Duration(seconds: 4),
    int persistenceWindow = 5,
    int persistenceHitsRequired = 3,
  })  : _db = spatialDb,
        _highValueLabels = {
          for (final label in (highValueLabels ?? defaultHighValueLabels))
            label.trim().toLowerCase(),
        },
        _minConfidence = minConfidence,
        _minLogInterval = minLogInterval,
        _persistenceWindow = persistenceWindow,
        _persistenceHitsRequired = persistenceHitsRequired {
    if (_highValueLabels.isEmpty) {
      throw const MemoryTrackerConfigException(
        'MemoryTracker requires a non-empty highValueLabels set.',
      );
    }
    if (_minConfidence < 0 || _minConfidence > 1) {
      throw const MemoryTrackerConfigException(
        'MemoryTracker minConfidence must be between 0 and 1 inclusive.',
      );
    }
    if (_minLogInterval.isNegative) {
      throw const MemoryTrackerConfigException(
        'MemoryTracker minLogInterval must not be negative.',
      );
    }
    if (_persistenceWindow < 1 ||
        _persistenceHitsRequired < 1 ||
        _persistenceHitsRequired > _persistenceWindow) {
      throw const MemoryTrackerConfigException(
        'persistenceHitsRequired must be in [1, persistenceWindow].',
      );
    }
  }

  final SpatialDb _db;
  final Set<String> _highValueLabels;
  final double _minConfidence;
  final Duration _minLogInterval;
  final int _persistenceWindow;
  final int _persistenceHitsRequired;
  final Map<String, DateTime> _lastLoggedAt = {};

  /// Per-label ring of recent frame hits (true = seen this frame).
  final Map<String, List<bool>> _hitWindows = {};
  final Map<String, _FrameHit> _latestHit = {};

  /// Shape placeholders — never ambient-speak or remember.
  static const Set<String> ephemeralShapeLabels = {
    'nearby thing',
    'tall thing',
    'wide thing',
    'low thing',
    'object',
    'unknown',
    'something',
  };

  /// Material / texture tags — never ambient speech (imprecise loops).
  static const Set<String> materialNoiseLabels = {
    'metal',
    'plastic',
    'textile',
    'fabric',
    'leather',
    'wood',
    'wooden',
    'rubber',
    'glass',
    'concrete',
    'asphalt',
    'material',
    'pattern',
    'texture',
    'surface',
    'sky',
    'cloud',
    'clouds',
    'monochrome',
    'grayscale',
    'greyscale',
    'screen',
    'furniture',
    'kitchen',
    'color',
    'colour',
  };

  /// Semantic synonym groups (canonical → aliases). System-wide, not per-object hacks.
  static const Map<String, List<String>> objectSynonymGroups = {
    'shoes': [
      'shoes',
      'shoe',
      'footwear',
      'sneaker',
      'sneakers',
      'boot',
      'boots',
      'sandal',
      'sandals',
      'slipper',
      'slippers',
    ],
    'laptop': [
      'laptop',
      'computer',
      'notebook computer',
      'laptop computer',
      'notebook',
      'screen',
      'tvmonitor',
      'monitor',
    ],
    'phone': ['phone', 'cell phone', 'mobile', 'smartphone', 'mobile phone'],
    'keys': ['keys', 'key'],
    'glasses': ['glasses', 'eyeglasses', 'spectacles'],
    'headphones': ['headphones', 'headset', 'earphones', 'earbuds'],
    'purse': ['purse', 'handbag', 'wallet', 'bag'],
    'backpack': ['backpack', 'rucksack'],
    'chair': ['chair', 'seat'],
    'table': ['table', 'desk'],
    'bottle': ['bottle', 'water bottle'],
    'tv': ['tv', 'television', 'tvmonitor', 'monitor', 'screen'],
    'person': ['person', 'people', 'man', 'woman', 'human'],
    'cup': ['cup', 'mug'],
    'book': ['book', 'books'],
    'door': ['door', 'doors'],
    'wall': ['wall', 'walls'],
  };

  /// True if [label] must never be spoken as ambient scene inventory.
  static bool isAmbientNoise(String label) {
    final n = SceneVocab.normalize(label.trim());
    if (n.isEmpty) {
      return true;
    }
    if (ephemeralShapeLabels.contains(n) || materialNoiseLabels.contains(n)) {
      return true;
    }
    return materialNoiseLabels.contains(label.trim().toLowerCase());
  }

  /// Expands [objectQuery] to normalized labels (stem + synonym groups).
  static List<String> expandSynonymQueries(String objectQuery) {
    final stripped = objectQuery
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^(my|the|a|an)\s+'), '');
    final query = SceneVocab.normalize(stripped);
    if (query.isEmpty) {
      return const [];
    }
    final out = <String>{query, stripped, _stem(query), _stem(stripped)};
    for (final entry in objectSynonymGroups.entries) {
      final canonical = SceneVocab.normalize(entry.key);
      final aliases = {
        canonical,
        _stem(canonical),
        ...entry.value.map(SceneVocab.normalize),
        ...entry.value.map(_stem),
      };
      final hit = aliases.any(
        (a) =>
            a.isNotEmpty &&
            (a == query ||
                a == stripped ||
                query.contains(a) ||
                a.contains(query) ||
                stripped.contains(a)),
      );
      if (hit) {
        out.addAll(aliases.where((a) => a.isNotEmpty));
      }
    }
    return out.toList();
  }

  /// Canonical storage label for a detection.
  static String canonicalStorageLabel(String normalizedLabel) {
    final n = normalizedLabel.trim().toLowerCase();
    for (final entry in objectSynonymGroups.entries) {
      final canonical = SceneVocab.normalize(entry.key);
      final aliases = {
        canonical,
        _stem(canonical),
        ...entry.value.map(SceneVocab.normalize),
        ...entry.value.map(_stem),
      };
      if (aliases.contains(n) || aliases.contains(_stem(n))) {
        return canonical;
      }
    }
    return SceneVocab.normalize(n).isEmpty ? n : SceneVocab.normalize(n);
  }

  /// Soft match score 0..1 between spoken request and detected label.
  static double semanticMatch(String detected, String requested) {
    final dRaw = SceneVocab.normalize(detected);
    final rRaw = SceneVocab.normalize(
      requested
          .trim()
          .toLowerCase()
          .replaceFirst(RegExp(r'^(my|the|a|an)\s+'), ''),
    );
    if (dRaw.isEmpty || rRaw.isEmpty) {
      return 0;
    }
    final d = canonicalStorageLabel(dRaw);
    final r = canonicalStorageLabel(rRaw);
    if (d == r) {
      return 1.0;
    }
    // Same synonym group only (avoids "bag" matching inside "backpack").
    final dAliases = {
      for (final a in expandSynonymQueries(d)) canonicalStorageLabel(a),
    };
    if (dAliases.contains(r)) {
      return 1.0;
    }
    final rAliases = {
      for (final a in expandSynonymQueries(r)) canonicalStorageLabel(a),
    };
    if (rAliases.contains(d)) {
      return 1.0;
    }
    if (d.length >= 4 && r.length >= 4 && (d.contains(r) || r.contains(d))) {
      return 0.85;
    }
    return 0;
  }

  static String _stem(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.endsWith('sses')) {
      return s.substring(0, s.length - 2);
    }
    if (s.endsWith('ies') && s.length > 4) {
      return '${s.substring(0, s.length - 3)}y';
    }
    if (s.endsWith('s') && !s.endsWith('ss') && s.length > 3) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  static const Set<String> defaultHighValueLabels = {
    'purse',
    'handbag',
    'backpack',
    'bag',
    'keys',
    'key',
    'medicine',
    'blister_pack',
    'syrup_bottle',
    'phone',
    'cell phone',
    'mobile',
    'glasses',
    'eyeglasses',
    'laptop',
    'computer',
    'keyboard',
    'headphones',
    'bottle',
    'chair',
    'table',
    'tvmonitor',
    'monitor',
    'screen',
    'notebook',
    'television',
    'tv',
    'shoes',
    'shoe',
    'footwear',
    'sneaker',
    'sneakers',
    'boot',
    'boots',
    'cup',
    'book',
    'door',
    'person',
  };

  /// Silently appends qualifying detections after multi-frame confirmation.
  Future<int> observeDetections({
    required String currentNodeId,
    required List<TrackedDetection> detections,
    DateTime? now,
    bool logAllLabels = false,
  }) async {
    final nodeId = currentNodeId.trim();
    if (nodeId.isEmpty) {
      throw const MemoryTrackerConfigException(
        'observeDetections requires a non-empty currentNodeId '
        '(current room/node must be known before logging).',
      );
    }
    if (!_db.isOpen) {
      throw const MemoryTrackerConfigException(
        'SpatialDb is not open. Call SpatialDb.open() before observeDetections.',
      );
    }

    final node = await _db.getNode(nodeId);
    if (node == null) {
      throw MemoryTrackerNotFoundException(
        'Cannot log memory: currentNodeId "$nodeId" does not exist in nodes.',
      );
    }

    final stamp = (now ?? DateTime.now()).toUtc();
    final seenThisFrame = <String>{};

    for (final detection in detections) {
      final rawLabel = SceneVocab.normalize(detection.label.trim());
      if (rawLabel.isEmpty ||
          ephemeralShapeLabels.contains(rawLabel) ||
          materialNoiseLabels.contains(rawLabel)) {
        continue;
      }
      final label = canonicalStorageLabel(rawLabel);
      if (!logAllLabels && !_highValueLabels.contains(label)) {
        continue;
      }
      // Close-up fill (>80% frame) may use a slightly lower confidence floor.
      final area = detection.boxArea;
      final closeUp = area != null && area >= 0.80;
      final minConf = closeUp ? (_minConfidence * 0.75) : _minConfidence;
      if (detection.confidence < minConf) {
        continue;
      }
      if (detection.confidence > 1.0) {
        throw MemoryTrackerConfigException(
          'Detection confidence for "$label" is ${detection.confidence}, '
          'which exceeds 1.0.',
        );
      }

      seenThisFrame.add(label);
      _latestHit[label] = _FrameHit(
        label: label,
        confidence: detection.confidence,
        relativeVectorX: detection.relativeVectorX,
        relativeVectorY: detection.relativeVectorY,
        depthZ: closeUp ? (detection.depthZ ?? 0.5) : detection.depthZ,
        boxArea: area,
      );
    }

    // Advance every tracked window for this frame.
    final tracked = {..._hitWindows.keys, ...seenThisFrame};
    for (final label in tracked) {
      final window = _hitWindows.putIfAbsent(
        label,
        () => List<bool>.filled(_persistenceWindow, false),
      );
      if (window.length >= _persistenceWindow) {
        window.removeAt(0);
      }
      window.add(seenThisFrame.contains(label));
      _hitWindows[label] = window;
    }

    var inserted = 0;
    for (final label in seenThisFrame) {
      final window = _hitWindows[label] ?? const <bool>[];
      final hits = window.where((h) => h).length;
      if (hits < _persistenceHitsRequired) {
        continue;
      }

      final last = _lastLoggedAt[label];
      if (last != null && stamp.difference(last) < _minLogInterval) {
        continue;
      }

      final hit = _latestHit[label];
      if (hit == null) {
        continue;
      }

      try {
        await _db.insertObjectMemory(
          ObjectMemoryRecord(
            objectLabel: label,
            associatedNode: nodeId,
            relativeVectorX: hit.relativeVectorX,
            relativeVectorY: hit.relativeVectorY,
            depthZ: hit.depthZ,
            timestamp: stamp,
          ),
        );
        _lastLoggedAt[label] = stamp;
        inserted += 1;
      } on SpatialDbException catch (error) {
        throw MemoryTrackerWriteException(
          'Silent object_memory insert failed for "$label": $error',
        );
      }
    }

    return inserted;
  }

  /// Fetches the newest historical row for [objectQuery] (synonym-aware).
  Future<MemoryRecallResult> locateLastSeen(String objectQuery) async {
    final query = objectQuery.trim();
    if (query.isEmpty) {
      throw const MemoryTrackerConfigException(
        'locateLastSeen requires a non-empty objectQuery.',
      );
    }
    if (!_db.isOpen) {
      throw const MemoryTrackerConfigException(
        'SpatialDb is not open. Call SpatialDb.open() before locateLastSeen.',
      );
    }

    ObjectMemoryRecord? record;
    try {
      final labels = expandSynonymQueries(query);
      record = await _db.locateLastSeenByAnyLabel(
        labels.isEmpty ? [query.toLowerCase()] : labels,
      );
    } on SpatialDbException catch (error) {
      throw MemoryTrackerWriteException(
        'locateLastSeen query failed for "$query": $error',
      );
    }

    if (record == null) {
      throw MemoryTrackerNotFoundException(
        'No memory found for "$query".',
      );
    }

    final node = await _db.getNode(record.associatedNode);
    if (node == null) {
      throw MemoryTrackerNotFoundException(
        'Memory for "${record.objectLabel}" points at missing node '
        '"${record.associatedNode}".',
      );
    }

    final spoken = _formatSpoken(record: record, node: node);
    return MemoryRecallResult(spoken: spoken, record: record, node: node);
  }

  String _formatSpoken({
    required ObjectMemoryRecord record,
    required SpatialNode node,
  }) {
    final when = _relativeAgo(record.timestamp.toLocal());
    final place = node.label;
    return 'I last saw your ${record.objectLabel} near $place $when.';
  }

  String _relativeAgo(DateTime local) {
    final now = DateTime.now();
    final delta = now.difference(local);
    if (delta.inSeconds < 45) {
      return 'just now';
    }
    if (delta.inMinutes < 60) {
      final m = delta.inMinutes.clamp(1, 59);
      return m == 1 ? '1 minute ago' : '$m minutes ago';
    }
    if (delta.inHours < 24) {
      final h = delta.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    }
    if (delta.inDays == 1) {
      return '1 day ago';
    }
    if (delta.inDays < 14) {
      return '${delta.inDays} days ago';
    }
    return 'on ${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
