import 'package:flutter_test/flutter_test.dart';

import 'package:visionaid/core/utils/context_priority_score.dart';

void main() {
  test('priority score increases with navigation risk', () {
    final low = calculatePriorityScore(
      confidence: 0.5,
      distance: 0.2,
      motion: 0.1,
      userIntent: 0.2,
      objectImportance: 0.2,
      navigationRisk: 0.1,
    );
    final high = calculatePriorityScore(
      confidence: 0.5,
      distance: 0.2,
      motion: 0.1,
      userIntent: 0.2,
      objectImportance: 0.2,
      navigationRisk: 1.0,
    );
    expect(high, greaterThan(low));
  });
}
