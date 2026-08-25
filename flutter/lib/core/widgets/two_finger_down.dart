/// Fires once when two fingers are on the screen at the same time.
class TwoFingerDown {
  TwoFingerDown({required this.onTwo});

  final void Function() onTwo;
  final Set<int> _ids = {};
  bool _fired = false;

  int get count => _ids.length;

  bool get blocked => _fired || _ids.length >= 2;

  void down(int pointer) {
    _ids.add(pointer);
    if (_ids.length >= 2 && !_fired) {
      _fired = true;
      onTwo();
    }
  }

  void up(int pointer) {
    _ids.remove(pointer);
    if (_ids.isEmpty) {
      _fired = false;
    }
  }
}
