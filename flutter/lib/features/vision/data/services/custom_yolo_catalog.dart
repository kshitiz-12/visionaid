/// Class names for VisionAid custom YOLO — order must match `data.yaml` / Colab training.
///
/// Phase 1: navigation hazards + INR notes + medicine packaging shapes.
/// Drop the trained `visionaid_custom.tflite` into `assets/models/` to activate.
class CustomYoloCatalog {
  CustomYoloCatalog._();

  static const assetModel = 'assets/models/visionaid_custom.tflite';
  static const assetNames = 'assets/models/visionaid_custom.names';

  /// Stable spoken labels (English). Hindi mapping lives in ResponseGenerator.
  static const classes = <String>[
    // Navigation hazards (walking)
    'stairs',
    'ladder',
    'pothole',
    'open_drain',
    'curb',
    'wet_floor_sign',
    'wall',
    'door',
    // Indian banknotes (home / one-shot)
    'inr_10',
    'inr_20',
    'inr_50',
    'inr_100',
    'inr_200',
    'inr_500',
    // Medicine packaging outlines (home)
    'blister_pack',
    'syrup_bottle',
    'dropper_bottle',
    'ointment_tube',
  ];

  static const hazards = {
    'stairs',
    'ladder',
    'pothole',
    'open_drain',
    'curb',
    'wet_floor_sign',
    'wall',
    'door',
    'obstacle',
  };

  static const money = {
    'inr_10',
    'inr_20',
    'inr_50',
    'inr_100',
    'inr_200',
    'inr_500',
    'money',
  };

  /// Set by [YoloObjectDetector.hasCustomModel] once assets are probed.
  static bool? modelBundled;

  static String? nameOf(int classIndex) {
    if (classIndex < 0 || classIndex >= classes.length) {
      return null;
    }
    return classes[classIndex];
  }

  static bool isHazard(String label) => hazards.contains(label);
  static bool isMoney(String label) => money.contains(label);
}
