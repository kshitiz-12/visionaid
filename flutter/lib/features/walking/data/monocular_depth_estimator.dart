import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Optional on-device MiDaS-style relative depth.
///
/// Drop `assets/models/midas_small.tflite` (256×256) to enable. Without it,
/// [available] is false and walking keeps box-size depth.
class MonocularDepthEstimator {
  MonocularDepthEstimator();

  static const assetModel = 'assets/models/midas_small.tflite';
  static const inputSize = 256;

  Interpreter? _interpreter;
  bool _probed = false;
  bool _available = false;
  Float32List? _lastMap; // normalized 0..1 inverse depth, size inputSize²
  DateTime? _lastAt;

  bool get available => _available;
  Float32List? get lastMap => _lastMap;
  DateTime? get lastAt => _lastAt;

  Future<bool> warmup() async {
    if (_probed) {
      return _available;
    }
    _probed = true;
    try {
      await rootBundle.load(assetModel);
      _interpreter = await Interpreter.fromAsset(assetModel);
      _available = true;
    } catch (_) {
      _available = false;
      _interpreter = null;
    }
    return _available;
  }

  /// Runs depth on a JPEG. Returns normalized inverse-depth map (near → 1).
  Future<Float32List?> estimateJpeg(Uint8List jpeg) async {
    if (!_available || _interpreter == null) {
      final ok = await warmup();
      if (!ok || _interpreter == null) {
        return null;
      }
    }
    try {
      final decoded = img.decodeImage(jpeg);
      if (decoded == null) {
        return null;
      }
      final resized = img.copyResize(
        decoded,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );
      final input = _preprocess(resized);
      final output = List.generate(
        inputSize,
        (_) => List<double>.filled(inputSize, 0),
      );
      _interpreter!.run(input, output);
      final flat = Float32List(inputSize * inputSize);
      var minV = double.infinity;
      var maxV = -double.infinity;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final v = output[y][x];
          if (v < minV) minV = v;
          if (v > maxV) maxV = v;
        }
      }
      final span = math.max(1e-6, maxV - minV);
      var i = 0;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          flat[i++] = ((output[y][x] - minV) / span).clamp(0.0, 1.0);
        }
      }
      _lastMap = flat;
      _lastAt = DateTime.now();
      return flat;
    } catch (_) {
      return null;
    }
  }

  /// Mean inverse-depth in a normalized bbox → approximate metres via fusion.
  double? metresInRegion({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double boxFallbackMetres,
  }) {
    final map = _lastMap;
    if (map == null) {
      return null;
    }
    final x0 = (left.clamp(0.0, 1.0) * (inputSize - 1)).floor();
    final x1 = (right.clamp(0.0, 1.0) * (inputSize - 1)).ceil();
    final y0 = (top.clamp(0.0, 1.0) * (inputSize - 1)).floor();
    final y1 = (bottom.clamp(0.0, 1.0) * (inputSize - 1)).ceil();
    if (x1 < x0 || y1 < y0) {
      return null;
    }
    var sum = 0.0;
    var n = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        sum += map[y * inputSize + x];
        n += 1;
      }
    }
    if (n == 0) {
      return null;
    }
    final inv = sum / n; // 1 = near
    // Relative → metres: blend inverse-depth scale with box-size prior.
    final fromMap = (0.45 / math.max(0.08, inv)).clamp(0.4, 6.0);
    return (fromMap * 0.65 + boxFallbackMetres * 0.35).clamp(0.4, 6.0);
  }

  List<List<List<double>>> _preprocess(img.Image image) {
    // ImageNet-ish normalize into roughly [-1, 1] for MiDaS small TFLite.
    final out = List.generate(
      inputSize,
      (_) => List.generate(inputSize, (_) => List<double>.filled(3, 0)),
    );
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final p = image.getPixel(x, y);
        out[y][x][0] = (p.r / 255.0 - 0.485) / 0.229;
        out[y][x][1] = (p.g / 255.0 - 0.456) / 0.224;
        out[y][x][2] = (p.b / 255.0 - 0.406) / 0.225;
      }
    }
    return out;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }

  @visibleForTesting
  void debugSetMap(Float32List map) {
    _lastMap = map;
    _lastAt = DateTime.now();
  }
}
