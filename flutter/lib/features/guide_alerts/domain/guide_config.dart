/// Initial engineering hypotheses for live-guide alerting. Not scientifically proven.
class GuideConfig {
  const GuideConfig({
    this.minimumConfidence = 0.38,
    this.veryLowConfidence = 0.22,
    this.requiredConfirmationFrames = 2,
    this.safetyConfirmationFrames = 2,
    this.neutralDistanceScore = 0.30,
    this.corridorLeft = 0.35,
    this.corridorRight = 0.65,
    this.confidenceWeight = 20,
    this.riskWeight = 20,
    this.pathWeight = 20,
    this.distanceWeight = 15,
    this.movementWeight = 10,
    this.intentWeight = 10,
    this.noveltyWeight = 5,
    this.announceThreshold = 60,
    this.highPriorityThreshold = 75,
    this.criticalThreshold = 90,
    this.lowPriorityThreshold = 40,
    this.targetMatchWeight = 40,
    this.targetConfidenceWeight = 25,
    this.targetDistanceWeight = 15,
    this.targetDirectionWeight = 10,
    this.targetTemporalWeight = 10,
    this.targetFoundScore = 75,
    this.targetMinConfidence = 0.70,
    this.targetWindowFrames = 4,
    this.targetSearchTimeout = const Duration(seconds: 12),
    this.announcementCooldown = const Duration(seconds: 8),
    this.minGapBetweenSpeech = const Duration(milliseconds: 2800),
    this.debugMode = false,
    this.researchLog = false,
    this.objectRisk = const {
      'vehicle': 0.90,
      'car': 0.90,
      'truck': 0.90,
      'bus': 0.90,
      'motorcycle': 0.90,
      'bicycle': 0.80,
      'stairs': 0.90,
      'wall': 0.95,
      'obstacle': 0.90,
      'person': 0.40,
      'people': 0.40,
      'dog': 0.50,
      'chair': 0.20,
      'table': 0.20,
      'bottle': 0.10,
      'laptop': 0.10,
      'phone': 0.10,
      'door': 0.30,
    },
    this.targetAliases = const {
      'purse': ['purse', 'handbag', 'bag'],
      'handbag': ['handbag', 'purse'],
      'backpack': ['backpack'],
      'door': ['door'],
      'chair': ['chair'],
      'bottle': ['bottle'],
      'person': ['person', 'people'],
      'laptop': ['laptop', 'computer'],
      'headphones': ['headphones', 'headset', 'earphones'],
    },
  });

  final double minimumConfidence;
  final double veryLowConfidence;
  final int requiredConfirmationFrames;
  final int safetyConfirmationFrames;
  final double neutralDistanceScore;
  final double corridorLeft;
  final double corridorRight;
  final double confidenceWeight;
  final double riskWeight;
  final double pathWeight;
  final double distanceWeight;
  final double movementWeight;
  final double intentWeight;
  final double noveltyWeight;
  final double announceThreshold;
  final double highPriorityThreshold;
  final double criticalThreshold;
  final double lowPriorityThreshold;
  final double targetMatchWeight;
  final double targetConfidenceWeight;
  final double targetDistanceWeight;
  final double targetDirectionWeight;
  final double targetTemporalWeight;
  final double targetFoundScore;
  final double targetMinConfidence;
  final int targetWindowFrames;
  final Duration targetSearchTimeout;
  final Duration announcementCooldown;
  final Duration minGapBetweenSpeech;
  final bool debugMode;
  final bool researchLog;
  final Map<String, double> objectRisk;
  final Map<String, List<String>> targetAliases;
}
