import '../entities/context_decision.dart';
import '../entities/prioritized_object.dart';

abstract class ContextEngine {
  /// Rank detections and decide what (if anything) to speak.
  ContextDecision evaluate({
    required List<Map<String, dynamic>> detections,
    required String intentTarget,
    double speakThreshold = 2.4,
  });

  List<PrioritizedObject> rank({
    required List<Map<String, dynamic>> detections,
    required String intentTarget,
  });
}
