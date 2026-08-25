import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:visionaid/features/vision/data/services/yolo_mapper.dart';

void main() {
  test('YOLO chair maps to named box with metres', () {
    final result = YOLOResult(
      classIndex: 56,
      className: 'chair',
      confidence: 0.82,
      boundingBox: const Rect.fromLTWH(80, 90, 200, 280),
      normalizedBox: const Rect.fromLTWH(0.36, 0.25, 0.28, 0.55),
    );
    final raw = YoloMapper.toRaw([result]);
    expect(raw, isNotEmpty);
    expect(raw.first.label, 'chair');
    expect(raw.first.distanceMeters, isNotNull);
    expect(raw.first.distanceMeters! < 4, isTrue);
  });

  test('YOLO drops empty object-class noise', () {
    final result = YOLOResult(
      classIndex: 0,
      className: 'object',
      confidence: 0.9,
      boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
      normalizedBox: const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
    );
    expect(YoloMapper.toRaw([result]), isEmpty);
  });
}
