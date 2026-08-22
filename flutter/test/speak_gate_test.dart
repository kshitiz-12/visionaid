import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/utils/speak_gate.dart';

void main() {
  test('does not repeat the same non-hazard line', () {
    final gate = SpeakGate(
      hazardGap: Duration.zero,
      normalGap: Duration.zero,
    );
    expect(gate.allow('Ahead: chair.', hazard: false), isTrue);
    expect(gate.allow('Ahead: chair.', hazard: false), isFalse);
  });

  test('allows a new scene after the previous one', () {
    final gate = SpeakGate(
      hazardGap: Duration.zero,
      normalGap: Duration.zero,
    );
    expect(gate.allow('Ahead: chair.', hazard: false), isTrue);
    expect(gate.allow('Caution. car nearby.', hazard: true), isTrue);
  });
}
