/// Explicit live-vision operating modes.
///
/// Hazard navigation and object search must not share the same speech loop.
enum AppVisionMode {
  /// Corridor / walking guide: hazards, path-clear, ambient scene (throttled).
  hazardNavigation,

  /// Object hunt: mute path-clear + ambient hazard chatter; focus on target.
  targetSearch,
}

/// Controls which vision-to-speech branch is active.
class AppModeController {
  AppModeController({AppVisionMode initial = AppVisionMode.hazardNavigation})
      : _mode = initial;

  AppVisionMode _mode;
  String _searchTarget = '';

  /// Immediate crash cutoff (metres) — only hazard that may interrupt search.
  static const crashCutoffMetres = 0.4;

  AppVisionMode get mode => _mode;
  String get searchTarget => _searchTarget;
  bool get isTargetSearch => _mode == AppVisionMode.targetSearch;
  bool get isHazardNavigation => _mode == AppVisionMode.hazardNavigation;

  /// Enter object-search mode for [target] (e.g. "shoes", "laptop").
  void enterTargetSearch(String target) {
    final t = target.trim();
    if (t.isEmpty) {
      enterHazardNavigation();
      return;
    }
    _searchTarget = t;
    _mode = AppVisionMode.targetSearch;
  }

  /// Return to walking / hazard guidance.
  void enterHazardNavigation() {
    _mode = AppVisionMode.hazardNavigation;
    _searchTarget = '';
  }

  /// Whether general path-clear TTS is allowed.
  bool get allowPathClearSpeech => isHazardNavigation;

  /// Ambient scene narration disabled until perception is trustworthy indoors.
  bool get allowAmbientSceneSpeech => false;

  /// Whether a hazard announcement may interrupt target search.
  ///
  /// Only immediate crash-range obstacles (< [crashCutoffMetres]) break mute.
  bool allowHazardInterrupt({
    required double? depthMetres,
    required bool safetyCritical,
  }) {
    if (isHazardNavigation) {
      return true;
    }
    if (!safetyCritical) {
      return false;
    }
    if (depthMetres == null) {
      return false;
    }
    return depthMetres < crashCutoffMetres;
  }
}
