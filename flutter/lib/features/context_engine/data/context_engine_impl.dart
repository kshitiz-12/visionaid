import '../../../../core/utils/context_priority_score.dart';
import '../domain/entities/context_decision.dart';
import '../domain/entities/prioritized_object.dart';
import '../domain/services/context_engine.dart';

/// Context Engine — unique VisionAid++ core.
/// Speaks only high-priority / relevant information.
class ContextEngineImpl implements ContextEngine {
  static const _importance = <String, double>{
    'person': 0.85,
    'car': 0.95,
    'truck': 0.95,
    'bus': 0.95,
    'motorcycle': 0.9,
    'bicycle': 0.75,
    'dog': 0.7,
    'cat': 0.4,
    'chair': 0.55,
    'couch': 0.5,
    'bed': 0.45,
    'dining table': 0.55,
    'toilet': 0.5,
    'tv': 0.35,
    'laptop': 0.4,
    'cell phone': 0.55,
    'microwave': 0.35,
    'oven': 0.4,
    'sink': 0.45,
    'refrigerator': 0.45,
    'book': 0.4,
    'clock': 0.35,
    'vase': 0.2,
    'scissors': 0.55,
    'teddy bear': 0.2,
    'hair drier': 0.25,
    'toothbrush': 0.25,
    'bottle': 0.35,
    'cup': 0.3,
    'fork': 0.3,
    'knife': 0.65,
    'spoon': 0.3,
    'bowl': 0.3,
    'banana': 0.25,
    'apple': 0.25,
    'sandwich': 0.25,
    'orange': 0.25,
    'broccoli': 0.2,
    'carrot': 0.2,
    'hot dog': 0.2,
    'pizza': 0.2,
    'donut': 0.2,
    'cake': 0.2,
    'potted plant': 0.25,
    'bench': 0.45,
    'parking meter': 0.3,
    'fire hydrant': 0.55,
    'stop sign': 0.9,
    'traffic light': 0.85,
    'backpack': 0.4,
    'umbrella': 0.35,
    'handbag': 0.4,
    'tie': 0.2,
    'suitcase': 0.45,
    'frisbee': 0.25,
    'skis': 0.3,
    'snowboard': 0.3,
    'sports ball': 0.3,
    'kite': 0.2,
    'baseball bat': 0.45,
    'baseball glove': 0.3,
    'skateboard': 0.4,
    'surfboard': 0.3,
    'tennis racket': 0.3,
    'wine glass': 0.35,
    'door': 0.8,
    'stairs': 0.9,
    'exit': 0.9,
    'sign': 0.75,
  };

  static const _navRisk = <String, double>{
    'car': 0.95,
    'truck': 0.95,
    'bus': 0.95,
    'motorcycle': 0.9,
    'bicycle': 0.7,
    'person': 0.45,
    'dog': 0.55,
    'stairs': 0.85,
    'fire hydrant': 0.5,
    'stop sign': 0.4,
    'traffic light': 0.35,
    'bench': 0.4,
    'chair': 0.5,
    'couch': 0.45,
    'dining table': 0.55,
    'knife': 0.6,
  };

  @override
  List<PrioritizedObject> rank({
    required List<Map<String, dynamic>> detections,
    required String intentTarget,
  }) {
    final target = intentTarget.trim().toLowerCase();
    final ranked = detections.map((d) {
      final label = (d['label'] as String? ?? 'object').toLowerCase();
      final confidence = (d['confidence'] as num? ?? 0).toDouble().clamp(0.0, 1.0);
      final distance = (d['distance'] as num? ?? 0.5).toDouble().clamp(0.0, 1.0);
      final isMoving = d['isMoving'] as bool? ?? false;
      final importance = (d['importance'] as num?)?.toDouble() ??
          _importance[label] ??
          0.35;
      final navigationRisk = (d['navigationRisk'] as num?)?.toDouble() ??
          _navRisk[label] ??
          0.2;
      final userIntentMatch = _intentMatch(label, target);

      final score = calculatePriorityScore(
        confidence: confidence,
        distance: distance,
        motion: isMoving ? 1.0 : 0.2,
        userIntent: userIntentMatch,
        objectImportance: importance,
        navigationRisk: navigationRisk,
      );

      return PrioritizedObject(
        label: label,
        confidence: confidence,
        distance: distance,
        isMoving: isMoving,
        importance: importance.clamp(0.0, 1.0),
        navigationRisk: navigationRisk.clamp(0.0, 1.0),
        userIntentMatch: userIntentMatch,
        priorityScore: score,
      );
    }).toList();

    ranked.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return ranked;
  }

  @override
  ContextDecision evaluate({
    required List<Map<String, dynamic>> detections,
    required String intentTarget,
    double speakThreshold = 2.4,
  }) {
    final ranked = rank(detections: detections, intentTarget: intentTarget);

    if (ranked.isEmpty) {
      return const ContextDecision(
        shouldSpeak: true,
        spokenMessage: 'I do not see a clear object ahead yet. Wait, then take a small step.',
        ranked: [],
        reason: 'empty_scene',
      );
    }

    final top = ranked.first;
    final hazards = ranked.where((o) => o.isHazard && o.distance >= 0.45).toList();

    if (hazards.isNotEmpty) {
      final h = hazards.first;
      return ContextDecision(
        shouldSpeak: true,
        spokenMessage: _hazardMessage(h),
        ranked: ranked,
        reason: 'hazard',
      );
    }

    if (intentTarget.isNotEmpty) {
      final matches = ranked.where((o) => o.label.contains(intentTarget) || intentTarget.contains(o.label)).toList();
      if (matches.isNotEmpty) {
        final m = matches.first;
        return ContextDecision(
          shouldSpeak: true,
          spokenMessage: _findMessage(m, intentTarget),
          ranked: ranked,
          reason: 'intent_match',
        );
      }
      return ContextDecision(
        shouldSpeak: true,
        spokenMessage: 'I could not find $intentTarget ahead. '
            'I see ${top.label} nearby.',
        ranked: ranked,
        reason: 'intent_miss',
      );
    }

    if (top.priorityScore < speakThreshold && !top.isHazard) {
      // Speak a short summary of top 1–2 only if above noise floor.
      if (top.priorityScore < speakThreshold * 0.75) {
        return ContextDecision(
          shouldSpeak: true,
          spokenMessage: 'I see ${top.label} nearby.',
          ranked: ranked,
          reason: 'low_priority_summary',
        );
      }
    }

    final second = ranked.length > 1 ? ranked[1] : null;
    final message = second != null && second.priorityScore >= speakThreshold * 0.85
        ? 'I see ${top.label}, and ${second.label}.'
        : 'I see ${top.label} ${_closeness(top.distance)}.';

    return ContextDecision(
      shouldSpeak: true,
      spokenMessage: message,
      ranked: ranked,
      reason: 'scene_summary',
    );
  }

  double _intentMatch(String label, String target) {
    if (target.isEmpty) {
      return 0.5;
    }
    if (label == target || label.contains(target) || target.contains(label)) {
      return 1.0;
    }
    // Related groups
    if (target == 'vehicle' &&
        (label.contains('car') ||
            label.contains('bus') ||
            label.contains('truck') ||
            label.contains('motorcycle'))) {
      return 0.95;
    }
    if (label.contains('handbag') ||
        label.contains('backpack') ||
        label.contains('suitcase') ||
        label.contains('purse')) {
      if (target == 'purse' || target == 'bag' || target == 'handbag') {
        return 1.0;
      }
    }
    return 0.25;
  }

  String _hazardMessage(PrioritizedObject h) {
    final motion = h.isMoving ? ' and moving' : '';
    return 'Stop. ${h.label} is ${_closeness(h.distance)}$motion. Stay still until I say you can walk.';
  }

  String _closeness(double distance) {
    if (distance >= 0.75) {
      return 'very close';
    }
    if (distance >= 0.5) {
      return 'nearby';
    }
    return 'ahead';
  }

  String _findMessage(PrioritizedObject m, String target) {
    final closeness = m.distance >= 0.7
        ? 'very close'
        : (m.distance >= 0.45 ? 'nearby' : 'further ahead');
    return '${m.label} is $closeness. Reach slowly toward it.';
  }
}
