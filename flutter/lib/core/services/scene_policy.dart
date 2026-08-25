import '../../features/intent/domain/entities/user_intent.dart';

/// Decides when the camera should fire. Knowledge questions must not steal
/// the mic for a photo.
class ScenePolicy {
  ScenePolicy._();

  static final _repeat = RegExp(
    r'(repeat|say\s+that\s+again|what\s+did\s+you\s+say|pardon|once\s+more|again\s+please|दोहराओ|फिर\s+से\s+बोलो|क्या\s+कहा)',
    caseSensitive: false,
  );

  static final _vision = RegExp(
    r"\b(in\s+front|ahead\s+of\s+me|around\s+me|look\s+around|what\s+do\s+you\s+see|describe\s+(the\s+)?(scene|room|view)|ye\s+kya|yeh\s+kya|ye\s+kya\s+hai|सामने\s*क्या|ये\s*क्या|क्या\s*दिख)\b",
    caseSensitive: false,
  );

  static final _deicticVision = RegExp(
    r"\b(what('?s|\s+is)\s+(that|this|it)\b|what\s+am\s+i\s+(holding|pointing)|this\s+(thing|object|photo)|that\s+(thing|object))",
    caseSensitive: false,
  );

  static final _knowledge = RegExp(
    r'\b(in\s+english|in\s+hindi|translate|meaning\s+of|how\s+do\s+i|how\s+to|recipe|joke|weather|plan|maths?|calculate|plus|minus|called|kehte\s+hain|matlab|kahani|story)\b',
    caseSensitive: false,
  );

  static bool wantsRepeat(String spoken) => _repeat.hasMatch(spoken.trim());

  static bool wantsCamera(UserIntent intent) {
    if (intent.type == IntentType.sceneDescribe ||
        intent.type == IntentType.findObject ||
        intent.type == IntentType.navigation ||
        intent.type == IntentType.readText) {
      return true;
    }
    if (intent.type != IntentType.conversation &&
        intent.type != IntentType.help &&
        intent.type != IntentType.unknown) {
      return false;
    }
    final t = intent.rawText;
    if (_knowledge.hasMatch(t) && !_vision.hasMatch(t) && !_deicticVision.hasMatch(t)) {
      return false;
    }
    return _vision.hasMatch(t) || _deicticVision.hasMatch(t);
  }
}
