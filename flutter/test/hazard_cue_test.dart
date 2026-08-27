import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/walking/data/hazard_cue.dart';

void main() {
  test('target beep interval shortens when closer and centered', () {
    final farSide = HazardCue.targetIntervalMs(metres: 3.0, centerX: 0.15);
    final nearCenter = HazardCue.targetIntervalMs(metres: 0.7, centerX: 0.5);
    expect(nearCenter, lessThan(farSide));
    expect(nearCenter, lessThanOrEqualTo(500));
    expect(farSide, greaterThanOrEqualTo(900));
  });
}
