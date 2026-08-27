import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'frame_throttle.dart';

/// Drops inference when the phone is still; ramps up when the user moves.
class MotionAdaptiveThrottle {
  MotionAdaptiveThrottle({
    this.movingIntervalMs = 90,
    this.stillIntervalMs = 480,
    this.stillAfter = const Duration(milliseconds: 1600),
  }) : _throttle = FrameThrottle(minIntervalMs: movingIntervalMs);

  final int movingIntervalMs;
  final int stillIntervalMs;
  final Duration stillAfter;

  final FrameThrottle _throttle;
  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime _lastMove = DateTime.now();
  bool _moving = true;

  Future<void> start() async {
    await stop();
    try {
      _sub = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen((e) {
        final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (mag > 1.15) {
          _lastMove = DateTime.now();
          if (!_moving) {
            _moving = true;
            _throttle.minIntervalMs = movingIntervalMs;
          }
        }
      });
    } catch (_) {
      _moving = true;
      _throttle.minIntervalMs = movingIntervalMs;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool shouldSkip({required bool busy, required int nowMs}) {
    final still =
        DateTime.now().difference(_lastMove) >= stillAfter;
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
