import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/utils/context_priority_score.dart';

void main() {
  group('context priority score', () {
    test('prioritizes threatening or highly relevant objects', () {
      final score = calculatePriorityScore(
        confidence: 0.9,
        distance: 0.8,
        motion: 0.7,
        userIntent: 0.9,
        objectImportance: 0.95,
        navigationRisk: 0.6,
      );

      expect(score, greaterThan(3.0));
      expect(score, closeTo(4.35, 0.5));
    });

    test('returns low score for weak and irrelevant signal', () {
      final score = calculatePriorityScore(
        confidence: 0.2,
        distance: 0.1,
        motion: 0.1,
        userIntent: 0.2,
        objectImportance: 0.3,
        navigationRisk: 0.1,
      );

      expect(score, lessThan(1.0));
      expect(score, closeTo(0.91, 0.2));
    });
  });
}
