import '../entities/user_intent.dart';

abstract class IntentEngine {
  Future<UserIntent> classify(String spokenText);
}
