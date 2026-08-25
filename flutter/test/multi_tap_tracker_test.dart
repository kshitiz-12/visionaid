import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/widgets/multi_tap_tracker.dart';
import 'package:visionaid/core/widgets/two_finger_down.dart';

void main() {
  test('one tap is speak', () {
    fakeAsync((async) {
      var fired = 0;
      final taps = MultiTapTracker(
        onSingle: () => fired = 1,
        onDouble: () => fired = 2,
        onTriple: () => fired = 3,
      );
      taps.tap();
      async.elapse(const Duration(milliseconds: 560));
      expect(fired, 1);
      taps.dispose();
    });
  });

  test('two taps are look ahead', () {
    fakeAsync((async) {
      var fired = 0;
      final taps = MultiTapTracker(
        onSingle: () => fired = 1,
        onDouble: () => fired = 2,
        onTriple: () => fired = 3,
      );
      taps.tap();
      taps.tap();
      async.elapse(const Duration(milliseconds: 560));
      expect(fired, 2);
      taps.dispose();
    });
  });

  test('three or more taps are emergency', () {
    fakeAsync((async) {
      var fired = 0;
      final taps = MultiTapTracker(
        onSingle: () => fired = 1,
        onDouble: () => fired = 2,
        onTriple: () => fired = 3,
      );
      taps.tap();
      taps.tap();
      taps.tap();
      taps.tap();
      async.elapse(const Duration(milliseconds: 560));
      expect(fired, 3);
      taps.dispose();
    });
  });

  test('two fingers down fires once', () {
    var n = 0;
    final pair = TwoFingerDown(onTwo: () => n += 1);
    pair.down(1);
    expect(n, 0);
    pair.down(2);
    expect(n, 1);
    pair.down(3);
    expect(n, 1);
    pair.up(3);
    pair.up(2);
    pair.up(1);
    pair.down(8);
    pair.down(9);
    expect(n, 2);
  });
}
