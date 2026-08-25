import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/sentence_buffer.dart';
import 'package:visionaid/core/services/speech_sanitizer.dart';
import 'package:visionaid/features/emergency/data/emergency_message.dart';
import 'package:visionaid/features/walking/data/box_size_depth_provider.dart';
import 'package:visionaid/features/walking/data/frame_throttle.dart';

void main() {
  test('ground-plane: lower in the frame is closer', () {
    final near = BoxSizeDepthProvider.metresFromFootY(0.92);
    final far = BoxSizeDepthProvider.metresFromFootY(0.40);
    expect(near, lessThan(far));
    expect(near, lessThan(1.2));
    expect(far, greaterThan(1.5));
  });

  test('table-level height ratio: taller box is closer', () {
    final close = BoxSizeDepthProvider.metresFromHeightRatio(0.45);
    final far = BoxSizeDepthProvider.metresFromHeightRatio(0.08);
    expect(close, lessThan(far));
  });

  test('speech sanitizer strips markdown', () {
    expect(
      SpeechSanitizer.clean('**Water bottle** at your 2 o\'clock.'),
      'Water bottle at your 2 o\'clock.',
    );
    expect(
      SpeechSanitizer.clean('# Heading\n- item'),
      'Heading item',
    );
  });

  test('frame throttle caps at 5 FPS while busy still skips', () {
    final gate = FrameThrottle(minIntervalMs: 200);
    expect(gate.shouldSkip(busy: false, nowMs: 1000), isFalse);
    expect(gate.shouldSkip(busy: false, nowMs: 1100), isTrue);
    expect(gate.shouldSkip(busy: false, nowMs: 1200), isFalse);
    expect(gate.shouldSkip(busy: true, nowMs: 1500), isTrue);
  });

  test('emergency SMS includes maps link when GPS is known', () {
    expect(
      EmergencyMessage.body(userName: 'Kshitiz', latitude: 19.07, longitude: 72.87),
      contains('maps.google.com/?q=19.07,72.87'),
    );
    expect(
      EmergencyMessage.body(userName: ''),
      contains('Location unavailable'),
    );
  });

  test('sentence buffer speaks the first complete sentence', () {
    final buf = SentenceBuffer();
    expect(buf.add('Bottle at 2 o\'clock.'), ['Bottle at 2 o\'clock.']);
    expect(buf.add(' It is '), isEmpty);
    expect(buf.add('on the table. Extra'), ['It is on the table.']);
    expect(buf.flush(), 'Extra');
  });

  test('sentence buffer does not chunk by word count', () {
    final buf = SentenceBuffer();
    final long =
        'This is a long clause without a period that should stay buffered until a real stop';
    expect(buf.add(long), isEmpty);
    expect(buf.flush(), long);
  });

  test('Hindi danda ends a sentence', () {
    final buf = SentenceBuffer();
    expect(buf.add('आलू आलू है।और'), ['आलू आलू है।']);
    expect(buf.flush(), 'और');
  });
}
