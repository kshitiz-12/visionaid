import '../domain/guide_config.dart';

class RiskEvaluator {
  const RiskEvaluator(this.config);

  final GuideConfig config;

  double riskFor(String label, {required bool inPath}) {
    final key = label.trim().toLowerCase();
    var risk = config.objectRisk[key] ?? 0.20;
    if (inPath && (key == 'obstacle' || key == 'wall')) {
      risk = 0.95;
    }
    return risk.clamp(0.0, 1.0);
  }
}
