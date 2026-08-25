/// Caps Look Ahead ML to about 5 FPS while [_busyFrame] still drops stacked work.
class FrameThrottle {
  FrameThrottle({this.minIntervalMs = 200});

  final int minIntervalMs;
  int _lastAcceptedMs = 0;

  bool shouldSkip({required bool busy, required int nowMs}) {
    if (busy) {
      return true;
    }
    if (_lastAcceptedMs > 0 && nowMs - _lastAcceptedMs < minIntervalMs) {
      return true;
    }
    _lastAcceptedMs = nowMs;
    return false;
  }
}
