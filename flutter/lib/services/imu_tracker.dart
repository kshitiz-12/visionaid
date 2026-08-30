import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'spatial_db.dart';

/// Which sensing backend produced the latest motion estimate.
enum ImuSource {
  /// Accelerometer step peaks + gyroscope/magnetometer heading.
  sensorsPlus,

  /// Step/heading derived from Geolocator velocity / bearing deltas.
  geolocatorFallback,
}

class ImuTrackerException implements Exception {
  const ImuTrackerException(this.message, {this.code = 'IMU_TRACKER'});

  final String message;
  final String code;

  @override
  String toString() => 'ImuTrackerException($code): $message';
}

class ImuTrackerConfigException extends ImuTrackerException {
  const ImuTrackerConfigException(super.message)
      : super(code: 'IMU_TRACKER_CONFIG');
}

class ImuTrackerPermissionException extends ImuTrackerException {
  const ImuTrackerPermissionException(super.message)
      : super(code: 'IMU_TRACKER_PERMISSION');
}

class ImuTrackerSensorException extends ImuTrackerException {
  const ImuTrackerSensorException(super.message)
      : super(code: 'IMU_TRACKER_SENSOR');
}

class ImuTrackerStateException extends ImuTrackerException {
  const ImuTrackerStateException(super.message)
      : super(code: 'IMU_TRACKER_STATE');
}

class ImuTrackerPersistException extends ImuTrackerException {
  const ImuTrackerPersistException(super.message)
      : super(code: 'IMU_TRACKER_PERSIST');
}

/// Snapshot of walk metrics during "Follow Me" teaching.
class ImuSample {
  const ImuSample({
    required this.stepCount,
    required this.headingDegrees,
    required this.source,
    required this.timestamp,
    this.distanceMetersHint,
  });

  final int stepCount;

  /// Compass-style heading in degrees \[0, 360).
  final double headingDegrees;
  final ImuSource source;
  final DateTime timestamp;

  /// Optional path length hint (mainly from Geolocator fallback).
  final double? distanceMetersHint;
}

/// Safe IMU wrapper: prefers `sensors_plus`, falls back to Geolocator deltas.
///
/// Also owns a **Follow Me** teaching session that persists a directed
/// [SpatialEdge] into [SpatialDb] when recording finishes.
class ImuTracker {
  ImuTracker({
    required SpatialDb spatialDb,
    this.metersPerStep = 0.75,
    this.stepPeakThreshold = 10.5,
    this.stepRefractory = const Duration(milliseconds: 320),
    this.sensorWarmup = const Duration(milliseconds: 900),
    this.geoDistanceFilterMeters = 1.0,
  }) : _db = spatialDb {
    if (metersPerStep <= 0) {
      throw const ImuTrackerConfigException(
        'metersPerStep must be > 0.',
      );
    }
    if (stepPeakThreshold <= 0) {
      throw const ImuTrackerConfigException(
        'stepPeakThreshold must be > 0.',
      );
    }
    if (stepRefractory.isNegative) {
      throw const ImuTrackerConfigException(
        'stepRefractory must not be negative.',
      );
    }
  }

  final SpatialDb _db;
  final double metersPerStep;
  final double stepPeakThreshold;
  final Duration stepRefractory;
  final Duration sensorWarmup;
  final double geoDistanceFilterMeters;

  final _samples = StreamController<ImuSample>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _running = false;
  bool _disposed = false;
  ImuSource _source = ImuSource.sensorsPlus;

  int _steps = 0;
  double _headingDegrees = 0;
  double? _lastAccelMag;
  DateTime? _lastStepAt;
  DateTime? _lastGyroAt;
  Position? _lastPosition;
  double _geoDistanceMeters = 0;

  String? _teachFromNodeId;
  DateTime? _teachStartedAt;
  double? _teachStartHeading;
  bool magnetometerActive = false;
  String? lastMagnetometerWarning;

  bool get isRunning => _running;
  bool get isTeaching => _teachFromNodeId != null;
  ImuSource get activeSource => _source;
  int get stepCount => _steps;
  double get headingDegrees => _headingDegrees;
  Stream<ImuSample> get samples => _samples.stream;

  /// Starts motion sensing (IMU first; auto-fallback to Geolocator).
  Future<void> start() async {
    _ensureAlive();
    if (_running) {
      throw const ImuTrackerStateException(
        'ImuTracker.start() called while already running.',
      );
    }
    _resetMotionCounters();
    _running = true;

    try {
      await _startSensorsPlus();
      _source = ImuSource.sensorsPlus;
      _emit();
    } on ImuTrackerException {
      await _startGeolocatorFallback(reason: 'sensors_plus start failed');
    } catch (error, stack) {
      await _startGeolocatorFallback(
        reason: 'sensors_plus unexpected failure: $error\n$stack',
      );
    }
  }

  /// Stops sensing. Does not finish an open teach session — call
  /// [cancelTeaching] or [finishTeaching] first.
  Future<void> stop() async {
    _ensureAlive();
    if (isTeaching) {
      throw const ImuTrackerStateException(
        'Cannot stop ImuTracker while a Follow Me session is active. '
        'Call finishTeaching() or cancelTeaching() first.',
      );
    }
    await _detachAll();
    _running = false;
  }

  /// Begins route teaching from an existing spatial node.
  Future<void> startTeaching({required String fromNodeId}) async {
    _ensureAlive();
    final from = fromNodeId.trim();
    if (from.isEmpty) {
      throw const ImuTrackerConfigException(
        'startTeaching requires a non-empty fromNodeId.',
      );
    }
    if (isTeaching) {
      throw const ImuTrackerStateException(
        'Follow Me teaching is already active.',
      );
    }
    if (!_db.isOpen) {
      throw const ImuTrackerPersistException(
        'SpatialDb is not open. Call SpatialDb.open() before startTeaching.',
      );
    }
    final node = await _db.getNode(from);
    if (node == null) {
      throw ImuTrackerPersistException(
        'fromNodeId "$from" does not exist in nodes.',
      );
    }
    if (!_running) {
      await start();
    }
    _teachFromNodeId = from;
    _teachStartedAt = DateTime.now().toUtc();
    _teachStartHeading = _headingDegrees;
    _resetMotionCounters(preserveHeading: true);
    _emit();
  }

  /// Ends teaching and upserts a directed edge into SQLite.
  Future<SpatialEdge> finishTeaching({
    required String toNodeId,
    double? metersPerStepOverride,
  }) async {
    _ensureAlive();
    final from = _teachFromNodeId;
    final started = _teachStartedAt;
    if (from == null || started == null) {
      throw const ImuTrackerStateException(
        'finishTeaching called without an active Follow Me session.',
      );
    }
    final to = toNodeId.trim();
    if (to.isEmpty) {
      throw const ImuTrackerConfigException(
        'finishTeaching requires a non-empty toNodeId.',
      );
    }
    if (to == from) {
      throw const ImuTrackerConfigException(
        'finishTeaching refuses self-loop edges (from == to).',
      );
    }
    if (!_db.isOpen) {
      throw const ImuTrackerPersistException(
        'SpatialDb is not open. Call SpatialDb.open() before finishTeaching.',
      );
    }
    final toNode = await _db.getNode(to);
    if (toNode == null) {
      throw ImuTrackerPersistException(
        'toNodeId "$to" does not exist in nodes.',
      );
    }

    final stepLen = metersPerStepOverride ?? metersPerStep;
    if (stepLen <= 0) {
      throw const ImuTrackerConfigException(
        'metersPerStepOverride must be > 0 when provided.',
      );
    }

    final steps = _steps;
    if (steps <= 0 && _geoDistanceMeters < 0.5) {
      throw const ImuTrackerStateException(
        'Follow Me session captured no steps/distance. '
        'Walk the path before finishTeaching().',
      );
    }

    final distance = _geoDistanceMeters > 0
        ? _geoDistanceMeters
        : steps * stepLen;
    final startHeading = _teachStartHeading ?? _headingDegrees;
    final headingDelta = _normalizeHeading(_headingDegrees - startHeading);

    final edge = SpatialEdge(
      fromNode: from,
      toNode: to,
      distanceMeters: distance,
      headingDegrees: headingDelta,
      stepCount: math.max(steps, (distance / stepLen).round()),
    );

    try {
      await _db.upsertEdge(edge);
    } on SpatialDbException catch (error) {
      throw ImuTrackerPersistException(
        'Failed to persist Follow Me edge $from → $to: $error',
      );
    }

    _teachFromNodeId = null;
    _teachStartedAt = null;
    _teachStartHeading = null;
    _emit();
    return edge;
  }

  /// Aborts teaching without writing an edge.
  Future<void> cancelTeaching() async {
    _ensureAlive();
    if (!isTeaching) {
      throw const ImuTrackerStateException(
        'cancelTeaching called without an active Follow Me session.',
      );
    }
    _teachFromNodeId = null;
    _teachStartedAt = null;
    _teachStartHeading = null;
    _emit();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _teachFromNodeId = null;
    _teachStartedAt = null;
    await _detachAll();
    _running = false;
    await _samples.close();
  }

  Future<void> _startSensorsPlus() async {
    final accelDone = Completer<void>();
    final gyroDone = Completer<void>();

    late final StreamSubscription<UserAccelerometerEvent> accelSub;
    accelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (event) {
        if (!accelDone.isCompleted) {
          accelDone.complete();
        }
        _onUserAccel(event);
      },
      onError: (Object error, StackTrace stack) {
        if (!accelDone.isCompleted) {
          accelDone.completeError(
            ImuTrackerSensorException(
              'userAccelerometerEventStream failed: $error\n$stack',
            ),
            stack,
          );
        } else {
          unawaited(
            _failoverToGeolocator(
              'userAccelerometer stream error: $error\n$stack',
            ),
          );
        }
      },
      cancelOnError: false,
    );
    _subs.add(accelSub);

    late final StreamSubscription<GyroscopeEvent> gyroSub;
    gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (event) {
        if (!gyroDone.isCompleted) {
          gyroDone.complete();
        }
        _onGyro(event);
      },
      onError: (Object error, StackTrace stack) {
        if (!gyroDone.isCompleted) {
          gyroDone.completeError(
            ImuTrackerSensorException(
              'gyroscopeEventStream failed: $error\n$stack',
            ),
            stack,
          );
        } else {
          unawaited(
            _failoverToGeolocator('gyroscope stream error: $error\n$stack'),
          );
        }
      },
      cancelOnError: false,
    );
    _subs.add(gyroSub);

    // Magnetometer is optional — improves absolute heading when present.
    try {
      final magSub = magnetometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        (event) {
          magnetometerActive = true;
          lastMagnetometerWarning = null;
          _onMagnetometer(event);
        },
        onError: (Object error, StackTrace stack) {
          magnetometerActive = false;
          lastMagnetometerWarning =
              'magnetometerEventStream error (gyro heading still active): '
              '$error';
        },
        cancelOnError: false,
      );
      _subs.add(magSub);
    } catch (error, stack) {
      magnetometerActive = false;
      lastMagnetometerWarning =
          'magnetometerEventStream subscribe failed (gyro heading still '
          'active): $error\n$stack';
    }

    try {
      await Future.wait<void>([
        accelDone.future.timeout(sensorWarmup),
        gyroDone.future.timeout(sensorWarmup),
      ]);
    } on TimeoutException {
      await _detachAll();
      throw const ImuTrackerSensorException(
        'sensors_plus produced no accelerometer/gyroscope events '
        'before warmup timeout.',
      );
    } on ImuTrackerSensorException {
      await _detachAll();
      rethrow;
    }
  }

  Future<void> _startGeolocatorFallback({required String reason}) async {
    await _detachAll();
    _source = ImuSource.geolocatorFallback;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _running = false;
      throw ImuTrackerPermissionException(
        'Geolocator fallback required ($reason) but location services '
        'are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _running = false;
      throw ImuTrackerPermissionException(
        'Geolocator fallback required ($reason) but location permission '
        'was denied ($permission).',
      );
    }

    final sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: geoDistanceFilterMeters.round().clamp(0, 100),
      ),
    ).listen(
      _onPosition,
      onError: (Object error, StackTrace stack) {
        unawaited(_failHard(
          ImuTrackerSensorException(
            'Geolocator position stream failed after sensors_plus fallback '
            '($reason): $error\n$stack',
          ),
        ));
      },
      cancelOnError: false,
    );
    _subs.add(sub);
    _running = true;
    _emit();
  }

  Future<void> _failoverToGeolocator(String reason) async {
    if (_disposed || _source == ImuSource.geolocatorFallback) {
      return;
    }
    try {
      await _startGeolocatorFallback(reason: reason);
    } on ImuTrackerException catch (error) {
      await _failHard(error);
    }
  }

  Future<void> _failHard(ImuTrackerException error) async {
    await _detachAll();
    _running = false;
    if (!_samples.isClosed) {
      _samples.addError(error);
    }
  }

  void _onUserAccel(UserAccelerometerEvent event) {
    final mag = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final prev = _lastAccelMag;
    _lastAccelMag = mag;
    if (prev == null) {
      return;
    }
    final now = DateTime.now();
    final cooled = _lastStepAt == null ||
        now.difference(_lastStepAt!) >= stepRefractory;
    // Rising-edge peak crossing for step-like impulses.
    if (cooled && prev < stepPeakThreshold && mag >= stepPeakThreshold) {
      _steps += 1;
      _lastStepAt = now;
      _emit();
    }
  }

  void _onGyro(GyroscopeEvent event) {
    final now = DateTime.now();
    final last = _lastGyroAt;
    _lastGyroAt = now;
    if (last == null) {
      return;
    }
    final dt = now.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) {
      return;
    }
    // Integrate yaw (rad/s → deg). Sign convention: device Z ≈ heading rate.
    final yawRateDeg = event.z * 180.0 / math.pi;
    _headingDegrees = _normalizeHeading(_headingDegrees + yawRateDeg * dt);
    _emit();
  }

  void _onMagnetometer(MagnetometerEvent event) {
    final heading = math.atan2(event.y, event.x) * 180.0 / math.pi;
    _headingDegrees = _normalizeHeading(heading);
    _emit();
  }

  void _onPosition(Position position) {
    final prev = _lastPosition;
    _lastPosition = position;
    if (position.heading >= 0) {
      _headingDegrees = _normalizeHeading(position.heading);
    }
    if (prev != null) {
      final delta = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        position.latitude,
        position.longitude,
      );
      if (delta.isFinite && delta > 0) {
        _geoDistanceMeters += delta;
        final addedSteps = (delta / metersPerStep).floor();
        if (addedSteps > 0) {
          _steps += addedSteps;
        } else if (delta >= geoDistanceFilterMeters * 0.5) {
          _steps += 1;
        }
        if (position.heading < 0) {
          final bearing = Geolocator.bearingBetween(
            prev.latitude,
            prev.longitude,
            position.latitude,
            position.longitude,
          );
          _headingDegrees = _normalizeHeading(bearing);
        }
      }
    }
    _emit();
  }

  void _emit() {
    if (_samples.isClosed) {
      return;
    }
    _samples.add(
      ImuSample(
        stepCount: _steps,
        headingDegrees: _headingDegrees,
        source: _source,
        timestamp: DateTime.now().toUtc(),
        distanceMetersHint:
            _geoDistanceMeters > 0 ? _geoDistanceMeters : null,
      ),
    );
  }

  void _resetMotionCounters({bool preserveHeading = false}) {
    _steps = 0;
    _geoDistanceMeters = 0;
    _lastAccelMag = null;
    _lastStepAt = null;
    _lastGyroAt = null;
    _lastPosition = null;
    if (!preserveHeading) {
      _headingDegrees = 0;
    }
  }

  Future<void> _detachAll() async {
    final copy = List<StreamSubscription<dynamic>>.from(_subs);
    _subs.clear();
    for (final sub in copy) {
      try {
        await sub.cancel();
      } catch (error, stack) {
        throw ImuTrackerSensorException(
          'Failed cancelling IMU subscription: $error\n$stack',
        );
      }
    }
  }

  double _normalizeHeading(double degrees) {
    var h = degrees % 360.0;
    if (h < 0) {
      h += 360.0;
    }
    return h;
  }

  void _ensureAlive() {
    if (_disposed) {
      throw const ImuTrackerConfigException('ImuTracker has been disposed.');
    }
  }
}
