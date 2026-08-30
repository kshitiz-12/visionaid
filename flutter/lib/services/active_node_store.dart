import 'package:shared_preferences/shared_preferences.dart';

/// In-memory + SharedPreferences anchor for the user's current spatial node.
class ActiveNodeStore {
  ActiveNodeStore();

  static const prefsKey = 'visionaid_active_node_id';

  String? _activeNodeId;
  bool _loaded = false;

  String? get activeNodeId => _activeNodeId;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(prefsKey)?.trim();
    _activeNodeId = (value == null || value.isEmpty) ? null : value;
    _loaded = true;
  }

  Future<void> setActive(String nodeId) async {
    final id = nodeId.trim();
    if (id.isEmpty) {
      throw ArgumentError('ActiveNodeStore.setActive requires a non-empty id.');
    }
    _activeNodeId = id;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, id);
  }

  Future<void> clear() async {
    _activeNodeId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  /// Returns active id or throws if unset (callers must handle prompting).
  String requireActive() {
    final id = _activeNodeId?.trim() ?? '';
    if (id.isEmpty) {
      throw StateError(
        'No active room node. Say "I am at my couch" after teaching places, '
        'or set a current location first.',
      );
    }
    return id;
  }
}
