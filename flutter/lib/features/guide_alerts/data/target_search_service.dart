import '../domain/guide_config.dart';
import '../domain/guide_models.dart';
import 'object_priority_engine.dart';

class TargetSearchService {
  TargetSearchService(this.config) : scoring = ObjectPriorityEngine(config);

  final GuideConfig config;
  final ObjectPriorityEngine scoring;

  double match(String detected, String requested) =>
      scoring.targetMatch(detected, requested);

  double score(TargetFactors factors) => scoring.targetScore(factors);

  bool isFound(double targetScore, double confidence) {
    return targetScore >= config.targetFoundScore &&
        confidence >= config.targetMinConfidence;
  }
}
