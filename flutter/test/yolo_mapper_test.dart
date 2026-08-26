import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:visionaid/features/vision/data/services/yolo_mapper.dart';
import 'package:visionaid/features/vision/domain/services/object_detector_service.dart';

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

  test('YOLO invents wall for large unlabeled path blob', () {
    final result = YOLOResult(
      classIndex: 0,
      className: 'unknown',
      confidence: 0.7,
      boundingBox: const Rect.fromLTWH(100, 50, 400, 500),
      normalizedBox: const Rect.fromLTWH(0.2, 0.1, 0.6, 0.8),
    );
    final raw = YoloMapper.toRaw([result]);
    expect(raw, isNotEmpty);
    expect(raw.first.label, 'wall');
    expect(raw.first.distanceMeters, isNotNull);
  });

  test('hazard labels become corridor stairs boxes', () {
    final boxes = YoloMapper.hazardBoxesFromLabels(const [
      RawDetection(label: 'stairs', confidence: 0.6, distance: 0.5),
    ]);
    expect(boxes, isNotEmpty);
    expect(boxes.first.label, 'stairs');
    expect(boxes.first.distanceMeters, 1.0);
  });
}
