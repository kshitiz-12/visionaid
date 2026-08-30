import 'frame_throttle.dart';

/// Drops inference when the scene is still; ramps up when detections move.
///
/// Uses walking-frame motion hints (no accelerometer package) so Android builds
/// do not need the sensors_plus Gradle classpath download.
class MotionAdaptiveThrottle {
  MotionAdaptiveThrottle({
    this.movingIntervalMs = 70,
    this.stillIntervalMs = 200,
    this.stillAfter = const Duration(milliseconds: 900),
  }) : _throttle = FrameThrottle(minIntervalMs: movingIntervalMs);

  final int movingIntervalMs;
  final int stillIntervalMs;
  final Duration stillAfter;

  final FrameThrottle _throttle;
  DateTime _lastMove = DateTime.now();
  bool _moving = true;
  double? _lastAnchorX;

  Future<void> start() async {
    _lastMove = DateTime.now();
    _moving = true;
    _throttle.minIntervalMs = movingIntervalMs;
  }

  Future<void> stop() async {}

  /// Call each accepted frame with a stable scene anchor (e.g. mean centerX).
  void noteScene({double? anchorX, bool forcedMove = false}) {
    if (forcedMove) {
      _lastMove = DateTime.now();
      return;
    }
    if (anchorX == null) {
      return;
    }
    final prev = _lastAnchorX;
    _lastAnchorX = anchorX;
    if (prev != null && (anchorX - prev).abs() >= 0.04) {
      _lastMove = DateTime.now();
    }
  }

  bool shouldSkip({required bool busy, required int nowMs}) {
    final still = DateTime.now().difference(_lastMove) >= stillAfter;
    if (still && _moving) {
      _moving = false;
      _throttle.minIntervalMs = stillIntervalMs;
    } else if (!still && !_moving) {
      _moving = true;
      _throttle.minIntervalMs = movingIntervalMs;
    }
    return _throttle.shouldSkip(busy: busy, nowMs: nowMs);
  }

  bool get isMoving => _moving;
}
