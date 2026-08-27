/// Caps Look Ahead ML. Interval can change for motion-adaptive FPS.
class FrameThrottle {
  FrameThrottle({this.minIntervalMs = 200});

  int minIntervalMs;
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
