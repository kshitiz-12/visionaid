/// Initial engineering hypotheses for live-guide alerting. Not scientifically proven.
class GuideConfig {
  const GuideConfig({
    this.minimumConfidence = 0.38,
    this.veryLowConfidence = 0.22,
    this.requiredConfirmationFrames = 1,
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
    this.announceThreshold = 55,
    this.highPriorityThreshold = 70,
    this.criticalThreshold = 88,
    this.lowPriorityThreshold = 40,
    this.targetMatchWeight = 40,
    this.targetConfidenceWeight = 25,
    this.targetDistanceWeight = 15,
    this.targetDirectionWeight = 10,
    this.targetTemporalWeight = 10,
    this.targetFoundScore = 55,
    this.targetMinConfidence = 0.40,
    this.targetWindowFrames = 2,
    this.targetSearchTimeout = const Duration(seconds: 45),
    this.announcementCooldown = const Duration(seconds: 4),
    this.minGapBetweenSpeech = const Duration(milliseconds: 1400),
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
      'ladder': 0.90,
      'pothole': 0.95,
      'open_drain': 0.95,
      'curb': 0.85,
      'wet_floor_sign': 0.80,
      'wall': 0.88,
      'obstacle': 0.85,
      'person': 0.40,
      'people': 0.40,
      'dog': 0.50,
      'chair': 0.20,
      'table': 0.20,
      'bottle': 0.10,
      'laptop': 0.10,
      'phone': 0.10,
      'door': 0.30,
      'inr_10': 0.05,
      'inr_20': 0.05,
      'inr_50': 0.05,
      'inr_100': 0.05,
      'inr_200': 0.05,
      'inr_500': 0.05,
      'blister_pack': 0.15,
      'syrup_bottle': 0.15,
      'dropper_bottle': 0.15,
      'ointment_tube': 0.15,
    },
    this.targetAliases = const {
      'purse': ['purse', 'handbag', 'bag', 'wallet'],
      'bag': ['bag', 'purse', 'handbag', 'backpack'],
      'handbag': ['handbag', 'purse', 'bag'],
      'wallet': ['wallet', 'purse'],
      'backpack': ['backpack', 'bag'],
      'door': ['door'],
      'chair': ['chair'],
      'table': ['table'],
      'bottle': ['bottle'],
      'phone': ['phone'],
      'person': ['person', 'people'],
      'laptop': ['laptop', 'computer', 'notebook computer', 'laptop computer'],
      'headphones': ['headphones', 'headset', 'earphones'],
      'keys': ['keys', 'key'],
      'shoes': [
        'shoes',
        'shoe',
        'footwear',
        'sneaker',
        'sneakers',
        'boot',
        'boots',
      ],
      'shoe': [
        'shoes',
        'shoe',
        'footwear',
        'sneaker',
        'sneakers',
        'boot',
        'boots',
      ],
      'money': [
        'money',
        'inr_10',
        'inr_20',
        'inr_50',
        'inr_100',
        'inr_200',
        'inr_500',
      ],
      'stairs': ['stairs', 'ladder'],
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

  /// Live look-ahead: safety-only — no ambient object narration.
  static const hazardOnly = GuideConfig(
    minimumConfidence: 0.55,
    veryLowConfidence: 0.30,
    announceThreshold: 100,
    lowPriorityThreshold: 80,
    announcementCooldown: Duration(seconds: 8),
    minGapBetweenSpeech: Duration(milliseconds: 3000),
    requiredConfirmationFrames: 3,
    safetyConfirmationFrames: 3,
  );

  /// @deprecated Prefer [hazardOnly] — ambient narration caused indoor false positives.
  static const liveScene = hazardOnly;
}
