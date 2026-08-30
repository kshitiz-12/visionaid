import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/spoken_confirm.dart';
import 'package:visionaid/services/spatial_fusion.dart';

void main() {
  test('close-range frame area bypasses metric 1 metre speech', () {
    final fusion = SpatialFusion(
      calibration: DepthMetricCalibration.visionAidMidasSmall,
    );
    final map = Float32List(16 * 16);
    for (var i = 0; i < map.length; i++) {
      map[i] = 0.2;
    }
    final vector = fusion.computeVector(
      label: 'laptop',
      depthMap: map,
      mapWidth: 16,
      mapHeight: 16,
      box: const NormalizedBoundingBox(x1: 0.1, y1: 0.1, x2: 0.9, y2: 0.9),
    );
    expect(vector.closeRangeOverride, isTrue);
    expect(vector.depthZMeters, lessThan(0.5));
    expect(vector.summary.toLowerCase(), contains('very close'));
    expect(vector.summary.toLowerCase(), isNot(contains('1 meter')));
  });

  test('phonetic choice index maps free/tree/to/won', () {
    expect(SpokenConfirm.choiceIndex('free', 3), 2);
    expect(SpokenConfirm.choiceIndex('tree', 3), 2);
    expect(SpokenConfirm.choiceIndex('to', 3), 1);
    expect(SpokenConfirm.choiceIndex('won', 3), 0);
    expect(SpokenConfirm.choiceIndex('ek', 3), 0);
  });

  test('digitsFromSpeech accepts homophones', () {
    expect(SpokenConfirm.digitsFromSpeech('nine eight seven won'), '9871');
    expect(SpokenConfirm.digitsFromSpeech('too three free'), '233');
  });
}
