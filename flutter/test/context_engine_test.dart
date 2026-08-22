import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/context_engine/data/context_engine_impl.dart';

void main() {
  final engine = ContextEngineImpl();

  test('raises hazards above furniture', () {
    final ranked = engine.rank(
      detections: [
        {
          'label': 'chair',
          'confidence': 0.9,
          'distance': 0.8,
          'isMoving': false,
        },
        {
          'label': 'car',
          'confidence': 0.85,
          'distance': 0.6,
          'isMoving': true,
        },
      ],
      intentTarget: '',
    );

    expect(ranked.first.label, 'car');
    expect(ranked.first.isHazard, isTrue);
  });

  test('speaks hazard caution first', () {
    final decision = engine.evaluate(
      detections: [
        {
          'label': 'car',
          'confidence': 0.9,
          'distance': 0.7,
          'isMoving': true,
        },
      ],
      intentTarget: '',
    );

    expect(decision.shouldSpeak, isTrue);
    expect(decision.reason, 'hazard');
    expect(decision.spokenMessage.toLowerCase(), contains('stop'));
  });

  test('matches find-object intent target', () {
    final decision = engine.evaluate(
      detections: [
        {
          'label': 'door',
          'confidence': 0.8,
          'distance': 0.55,
          'isMoving': false,
          'importance': 0.8,
          'navigationRisk': 0.2,
        },
        {
          'label': 'chair',
          'confidence': 0.9,
          'distance': 0.9,
          'isMoving': false,
        },
      ],
      intentTarget: 'door',
    );

    expect(decision.reason, 'intent_match');
    expect(decision.spokenMessage.toLowerCase(), contains('door'));
  });
}
