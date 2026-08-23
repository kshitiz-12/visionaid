class WalkingLatency {
  WalkingLatency();

  int? frameCapturedMs;
  int? inferenceStartedMs;
  int? inferenceCompletedMs;
  int? depthCompletedMs;
  int? trackingCompletedMs;
  int? decisionCompletedMs;
  int? ttsTriggeredMs;

  int get cameraToDetectionMs {
    if (frameCapturedMs == null || inferenceCompletedMs == null) {
      return -1;
    }
    return inferenceCompletedMs! - frameCapturedMs!;
  }

  int get detectionToDecisionMs {
    if (inferenceCompletedMs == null || decisionCompletedMs == null) {
      return -1;
    }
    return decisionCompletedMs! - inferenceCompletedMs!;
  }

  int get decisionToTtsMs {
    if (decisionCompletedMs == null || ttsTriggeredMs == null) {
      return -1;
    }
    return ttsTriggeredMs! - decisionCompletedMs!;
  }

  int get hazardToTtsMs {
    if (frameCapturedMs == null || ttsTriggeredMs == null) {
      return -1;
    }
    return ttsTriggeredMs! - frameCapturedMs!;
  }

  String debugLine({required double fps}) {
    return 'cam→det ${cameraToDetectionMs}ms  '
        'det→dec ${detectionToDecisionMs}ms  '
        'dec→tts ${decisionToTtsMs}ms  '
        'total ${hazardToTtsMs}ms  fps ${fps.toStringAsFixed(1)}';
  }
}
