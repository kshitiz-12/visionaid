class TemporalConfirmationService {
  TemporalConfirmationService({this.window = 8});

  final int window;
  final Map<String, List<double>> _confidences = {};
  final Set<String> _seenThisFrame = {};

  void beginFrame() {
    _seenThisFrame.clear();
  }

  void observe(String trackKey, double confidence) {
    _seenThisFrame.add(trackKey);
    final list = _confidences.putIfAbsent(trackKey, () => <double>[]);
    list.add(confidence);
    while (list.length > window) {
      list.removeAt(0);
    }
  }

  void endFrame() {
    final stale = _confidences.keys.where((k) => !_seenThisFrame.contains(k)).toList();
    for (final key in stale) {
      _confidences.remove(key);
    }
  }

  int consecutiveFrames(String trackKey) => _confidences[trackKey]?.length ?? 0;

  bool confirmed(String trackKey, int required) {
    return consecutiveFrames(trackKey) >= required;
  }

  double consistency(String trackKey, int windowFrames) {
    final list = _confidences[trackKey];
    if (list == null || windowFrames <= 0) {
      return 0;
    }
    final n = list.length > windowFrames ? windowFrames : list.length;
    return (n / windowFrames).clamp(0.0, 1.0);
  }
}
