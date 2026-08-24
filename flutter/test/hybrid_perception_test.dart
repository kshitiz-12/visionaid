import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/speech_sanitizer.dart';
import 'package:visionaid/features/walking/data/box_size_depth_provider.dart';

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
}
