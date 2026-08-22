/// Prevents TTS flooding during live detection.
class SpeakGate {
  SpeakGate({
    this.hazardGap = const Duration(milliseconds: 1600),
    this.normalGap = const Duration(seconds: 4),
  });

  final Duration hazardGap;
  final Duration normalGap;

  DateTime? _last;
  String _lastMessage = '';

  bool allow(String message, {required bool hazard}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    if (!hazard && trimmed == _lastMessage) {
      return false;
    }

    if (_last != null) {
      final elapsed = now.difference(_last!);
      final minGap = hazard ? hazardGap : normalGap;
      if (elapsed < minGap) {
        return false;
      }
    }

    _last = now;
    _lastMessage = trimmed;
    return true;
  }

  void reset() {
    _last = null;
    _lastMessage = '';
  }
}
