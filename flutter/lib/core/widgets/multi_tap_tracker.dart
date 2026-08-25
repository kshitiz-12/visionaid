import 'dart:async';

/// Counts taps in a short window: 1 / 2 / 3+.
class MultiTapTracker {
  MultiTapTracker({
    this.window = const Duration(milliseconds: 520),
    this.onSingle,
    this.onDouble,
    this.onTriple,
  });

  final Duration window;
  final void Function()? onSingle;
  final void Function()? onDouble;
  final void Function()? onTriple;

  int _count = 0;
  Timer? _timer;

  void tap() {
    _count += 1;
    _timer?.cancel();
    _timer = Timer(window, _fire);
  }

  void reset() {
    _timer?.cancel();
    _count = 0;
  }

  void _fire() {
    final n = _count;
    _count = 0;
    if (n >= 3) {
      onTriple?.call();
    } else if (n == 2) {
      onDouble?.call();
    } else if (n == 1) {
      onSingle?.call();
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
