import '../../../intent/data/intent_engine_impl.dart';
import '../../../intent/domain/entities/user_intent.dart';
import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_context.dart';
import '../../domain/repositories/voice_repository.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  VoiceRepositoryImpl({IntentEngineImpl? intentEngine})
      : _intentEngine = intentEngine ?? IntentEngineImpl();

  final IntentEngineImpl _intentEngine;

  @override
  Future<VoiceCommand> classifyCommand(String spokenText) async {
    final intent = await _intentEngine.classify(spokenText);
    return VoiceCommand(
      rawText: intent.rawText.isEmpty ? spokenText.trim() : intent.rawText,
      intent: _legacyIntentName(intent.type),
      confidence: intent.confidence,
      isActionable: intent.isActionable,
    );
  }

  @override
  Future<VoiceContext> buildContext({required String spokenText}) async {
    final intent = await _intentEngine.classify(spokenText);
    final lower = spokenText.trim().toLowerCase();
    final legacy = _legacyIntentName(intent.type);

    final urgency = intent.type == IntentType.emergency
        ? 'high'
        : (intent.type == IntentType.navigation ||
                intent.type == IntentType.readText
            ? 'medium'
            : 'low');

    return VoiceContext(
      intent: legacy,
      location: lower.contains('outside') ? 'outdoor' : 'indoor',
      userMood: intent.type == IntentType.emergency ? 'alert' : 'focused',
      environment: lower.contains('outside') ? 'outdoor' : 'indoor',
      urgency: urgency,
      target: intent.target.isEmpty
          ? (intent.contactName.isEmpty ? 'environment' : intent.contactName)
          : intent.target,
    );
  }

  String _legacyIntentName(IntentType type) => switch (type) {
        IntentType.emergency => 'emergency',
        IntentType.navigation => 'navigation',
        IntentType.readText => 'read_text',
        IntentType.findObject => 'find_object',
        IntentType.sceneDescribe => 'scene_describe',
        IntentType.communication => 'communication',
        IntentType.help => 'help',
        IntentType.conversation => 'conversation',
        IntentType.cancel => 'cancel',
        IntentType.quit => 'quit',
        IntentType.unknown => 'general',
      };
}
